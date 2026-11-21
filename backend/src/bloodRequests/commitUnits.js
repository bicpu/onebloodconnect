/**
 * Atomically records a donor's unit commitment on one request document.
 * The caller keeps this write in the surrounding transaction when it also
 * changes donor state.
 */
async function commitUnits({
  BloodRequest,
  request,
  uid,
  units,
  responderName,
  session,
  now = new Date(),
}) {
  if (['fulfilled', 'cancelled'].includes(request.status)) {
    return { reason: 'request_not_available' };
  }
  if (request.expiresAt && request.expiresAt <= now) {
    return { reason: 'request_expired' };
  }

  const availableUnits = request.unitsRemaining == null
    ? request.units
    : request.unitsRemaining;
  const unitsCommitted = Math.min(units, availableUnits);
  if (unitsCommitted < 1) return { reason: 'no_units_remaining' };

  const remainingAfterCommit = availableUnits - unitsCommitted;
  const filter = {
    _id: request._id,
    status: request.status,
    'responses.responderUid': { $ne: uid },
    $or: [
      { expiresAt: null },
      { expiresAt: { $exists: false } },
      { expiresAt: { $gt: now } },
    ],
  };
  const update = {
    $push: {
      responses: {
        responderUid: uid,
        responderName: responderName || '',
        unitsCommitted,
        respondedAt: now,
      },
      timeline: {
        $each: [{
          step: 'Donor Responded',
          time: now,
          note: `${responderName || 'A donor'} committed ${unitsCommitted} unit${unitsCommitted !== 1 ? 's' : ''}`,
        }],
      },
    },
  };

  if (request.unitsRemaining == null) {
    // Legacy requests may have no initialized counter. Match the null value
    // and original total so concurrent initialization cannot oversubscribe it.
    filter.unitsRemaining = null;
    filter.units = { $gte: unitsCommitted };
    update.$set = { unitsRemaining: remainingAfterCommit };
  } else {
    filter.unitsRemaining = { $gte: unitsCommitted };
    update.$inc = { unitsRemaining: -unitsCommitted };
  }

  if (remainingAfterCommit === 0) {
    update.$set = { ...(update.$set || {}), status: 'fulfilled' };
    update.$push.timeline.$each.push({
      step: 'Request Fulfilled',
      time: now,
      note: 'All required units have been committed by donors',
    });
  }

  const committedRequest = await BloodRequest.findOneAndUpdate(
    filter,
    update,
    { new: true, runValidators: true, session },
  ).select('+targetFacilityAccountId +targetFacilityDirectoryId');

  return committedRequest ? { request: committedRequest, unitsCommitted } : null;
}

async function withdrawUnits({ BloodRequest, request, uid, session, now = new Date() }) {
  const response = request.responses.find((item) => item.responderUid === uid);
  if (!response) return { reason: 'commitment_not_found' };
  if (!response._id) return { reason: 'commitment_invalid' };

  const unitsToRestore = response.unitsCommitted;
  const currentRemaining = request.unitsRemaining == null ? 0 : request.unitsRemaining;
  if (currentRemaining + unitsToRestore > request.units) {
    return { reason: 'request_units_inconsistent' };
  }
  const update = {
    $pull: { responses: { _id: response._id } },
    $push: {
      timeline: {
        $each: [
          ...(request.status === 'fulfilled' ? [{
            step: 'Re-opened',
            time: now,
            note: `${response.responderName || 'A donor'} withdrew — ${unitsToRestore} unit${unitsToRestore !== 1 ? 's' : ''} need(s) a new donor`,
          }] : []),
          {
            step: 'Donor Withdrew',
            time: now,
            note: `${response.responderName || 'A donor'} cancelled their commitment of ${unitsToRestore} unit${unitsToRestore !== 1 ? 's' : ''}`,
          },
        ],
      },
    },
  };
  if (request.unitsRemaining == null) {
    update.$set = { unitsRemaining: unitsToRestore };
  } else {
    update.$inc = { unitsRemaining: unitsToRestore };
  }
  if (request.status === 'fulfilled') update.$set = { ...(update.$set || {}), status: 'received' };

  const updatedRequest = await BloodRequest.findOneAndUpdate({
    _id: request._id,
    status: request.status,
    unitsRemaining: request.unitsRemaining,
    responses: {
      $elemMatch: { _id: response._id, responderUid: uid, unitsCommitted: unitsToRestore },
    },
    units: { $gte: currentRemaining + unitsToRestore },
  }, update, { new: true, runValidators: true, session });

  return updatedRequest ? { request: updatedRequest, unitsRestored: unitsToRestore } : null;
}

module.exports = { commitUnits, withdrawUnits };
