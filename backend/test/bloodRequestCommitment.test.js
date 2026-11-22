const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { commitUnits, withdrawUnits } = require('../src/bloodRequests/commitUnits');

const backendRoot = path.resolve(__dirname, '..');
const routeSource = fs.readFileSync(path.join(backendRoot, 'src/routes/bloodRequests.js'), 'utf8');

function queryReturning(value) {
  return { select: async () => value };
}

test('commit write atomically filters on remaining units, duplicate donor, status, and expiry', async () => {
  let captured;
  const fakeModel = {
    findOneAndUpdate(filter, update, options) {
      captured = { filter, update, options };
      return queryReturning({ _id: 'request-id' });
    },
  };
  const request = {
    _id: 'request-id', status: 'received', units: 3, unitsRemaining: 2,
    expiresAt: new Date(Date.now() + 60_000),
  };
  const result = await commitUnits({
    BloodRequest: fakeModel, request, uid: 'donor-a', units: 2,
    responderName: 'Donor A', session: 'session',
  });

  assert.equal(result.unitsCommitted, 2);
  assert.deepEqual(captured.filter.unitsRemaining, { $gte: 2 });
  assert.deepEqual(captured.filter['responses.responderUid'], { $ne: 'donor-a' });
  assert.equal(captured.filter.status, 'received');
  assert.equal(captured.update.$inc.unitsRemaining, -2);
  assert.equal(captured.options.session, 'session');
  assert.ok(captured.update.$push.responses);
});

test('legacy null remaining count is initialized conditionally and terminal/expired requests are rejected', async () => {
  let capturedFilter;
  const fakeModel = {
    findOneAndUpdate(filter) {
      capturedFilter = filter;
      return queryReturning({ _id: 'request-id' });
    },
  };
  const request = {
    _id: 'request-id', status: 'received', units: 2, unitsRemaining: null,
    expiresAt: new Date(Date.now() + 60_000),
  };
  await commitUnits({ BloodRequest: fakeModel, request, uid: 'donor-a', units: 1 });
  assert.equal(capturedFilter.unitsRemaining, null);
  assert.deepEqual(capturedFilter.units, { $gte: 1 });

  for (const status of ['fulfilled', 'cancelled']) {
    const result = await commitUnits({
      BloodRequest: fakeModel,
      request: { ...request, status }, uid: 'donor-b', units: 1,
    });
    assert.equal(result.reason, 'request_not_available');
  }
  const expired = await commitUnits({
    BloodRequest: fakeModel,
    request: { ...request, expiresAt: new Date(Date.now() - 60_000) },
    uid: 'donor-b', units: 1,
  });
  assert.equal(expired.reason, 'request_expired');
});

test('withdrawal atomically matches the caller response and restores no more than requested units', async () => {
  let captured;
  const fakeModel = {
    findOneAndUpdate(filter, update, options) {
      captured = { filter, update, options };
      return queryReturning({ _id: 'request-id' });
    },
  };
  const request = {
    _id: 'request-id', status: 'fulfilled', units: 2, unitsRemaining: 0,
    responses: [{ _id: 'response-id', responderUid: 'donor-a', responderName: 'Donor A', unitsCommitted: 2 }],
  };
  const result = await withdrawUnits({
    BloodRequest: fakeModel, request, uid: 'donor-a', session: 'session',
  });
  assert.equal(result.unitsRestored, 2);
  assert.equal(captured.filter.status, 'fulfilled');
  assert.equal(captured.filter.responses.$elemMatch._id, 'response-id');
  assert.equal(captured.filter.responses.$elemMatch.responderUid, 'donor-a');
  assert.equal(captured.update.$inc.unitsRemaining, 2);
  assert.equal(captured.update.$pull.responses._id, 'response-id');
  assert.equal(captured.update.$set.status, 'received');
  assert.equal(captured.options.session, 'session');

  const otherDonor = await withdrawUnits({
    BloodRequest: fakeModel, request, uid: 'donor-b',
  });
  assert.equal(otherDonor.reason, 'commitment_not_found');
  const inconsistent = await withdrawUnits({
    BloodRequest: fakeModel,
    request: { ...request, unitsRemaining: 1 }, uid: 'donor-a',
  });
  assert.equal(inconsistent.reason, 'request_units_inconsistent');
});

test('response and withdrawal routes retain authenticated identity and transaction boundaries', () => {
  assert.match(routeSource, /router\.use\(authenticate\)/);
  assert.match(routeSource, /uid: req\.uid,[\s\S]*session,/);
  assert.match(routeSource, /runInTransaction\(async \(session\)/);
  assert.match(routeSource, /withdrawUnits\(\{[\s\S]*uid: req\.uid,[\s\S]*session,/);
  assert.match(routeSource, /activeCommitmentRequestId: request\._id\.toString\(\)/);
});

const mongoTestUri = process.env.ONEBLOOD_MONGODB_TEST_URI;
test('MongoDB integration: concurrent commitments never exceed units and withdrawal restores once',
  { skip: !mongoTestUri && 'Set ONEBLOOD_MONGODB_TEST_URI to a disposable test database to run.' },
  async () => {
    const databaseName = new URL(mongoTestUri).pathname.replace(/^\//, '').split('/')[0];
    assert.match(databaseName, /test/i, 'refusing to run unless the database name contains "test"');

    const mongoose = require('mongoose');
    const BloodRequest = require('../src/models/BloodRequest');
    const prefix = `issue09-${Date.now()}-`;
    await mongoose.connect(mongoTestUri, { serverSelectionTimeoutMS: 5000 });
    try {
      const createRequest = (units) => BloodRequest.create({
        requesterUid: `${prefix}requester`,
        patientName: 'Test Patient',
        bloodGroup: 'O+',
        units,
        unitsRemaining: units,
        status: 'received',
        expiresAt: new Date(Date.now() + 60 * 60 * 1000),
      });

      const lastUnitRequest = await createRequest(1);
      const [snapshotA, snapshotB] = await Promise.all([
        BloodRequest.findById(lastUnitRequest._id),
        BloodRequest.findById(lastUnitRequest._id),
      ]);
      const lastUnitResults = await Promise.all([
        commitUnits({ BloodRequest, request: snapshotA, uid: `${prefix}donor-a`, units: 1 }),
        commitUnits({ BloodRequest, request: snapshotB, uid: `${prefix}donor-b`, units: 1 }),
      ]);
      assert.equal(lastUnitResults.filter(Boolean).length, 1);
      let saved = await BloodRequest.findById(lastUnitRequest._id).lean();
      assert.equal(saved.unitsRemaining, 0);
      assert.equal(saved.responses.reduce((sum, response) => sum + response.unitsCommitted, 0), 1);
      assert.equal(saved.responses.length, 1);
      assert.equal(saved.status, 'fulfilled');

      const winningUid = saved.responses[0].responderUid;
      const retry = await commitUnits({
        BloodRequest,
        request: await BloodRequest.findById(lastUnitRequest._id),
        uid: winningUid,
        units: 1,
      });
      assert.equal(
        retry.reason,
        'request_not_available',
        'a retry after fulfillment must be rejected as unavailable',
      );
      const withdrawal = await withdrawUnits({
        BloodRequest,
        request: await BloodRequest.findById(lastUnitRequest._id),
        uid: winningUid,
      });
      assert.equal(withdrawal.unitsRestored, 1);
      saved = await BloodRequest.findById(lastUnitRequest._id).lean();
      assert.equal(saved.unitsRemaining, 1);
      assert.equal(saved.responses.length, 0);
      assert.equal(saved.status, 'received');
      const duplicateWithdrawal = await withdrawUnits({
        BloodRequest,
        request: await BloodRequest.findById(lastUnitRequest._id),
        uid: winningUid,
      });
      assert.equal(duplicateWithdrawal.reason, 'commitment_not_found');
      assert.equal((await BloodRequest.findById(lastUnitRequest._id)).unitsRemaining, 1);

      const insufficientRequest = await createRequest(3);
      const [snapshotC, snapshotD] = await Promise.all([
        BloodRequest.findById(insufficientRequest._id),
        BloodRequest.findById(insufficientRequest._id),
      ]);
      const overCapacityResults = await Promise.all([
        commitUnits({ BloodRequest, request: snapshotC, uid: `${prefix}donor-c`, units: 2 }),
        commitUnits({ BloodRequest, request: snapshotD, uid: `${prefix}donor-d`, units: 2 }),
      ]);
      assert.equal(overCapacityResults.filter(Boolean).length, 1);
      saved = await BloodRequest.findById(insufficientRequest._id).lean();
      const committedTotal = saved.responses.reduce((sum, response) => sum + response.unitsCommitted, 0);
      assert.ok(committedTotal <= saved.units);
      assert.equal(saved.unitsRemaining + committedTotal, saved.units);
    } finally {
      await BloodRequest.deleteMany({ requesterUid: { $regex: `^${prefix}` } });
      await mongoose.disconnect();
    }
  });
