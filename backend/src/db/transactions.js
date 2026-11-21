class TransactionUnavailableError extends Error {
  constructor(cause) {
    super('MongoDB transactions are unavailable for this deployment', { cause });
    this.name = 'TransactionUnavailableError';
    this.code = 'transactions_unavailable';
  }
}

function isTransactionUnsupported(error) {
  return error?.code === 20 || error?.codeName === 'IllegalOperation' ||
    /Transaction numbers are only allowed|does not support transactions|replica set/i
      .test(String(error?.message || ''));
}

function createTransactionRunner(startSession) {
  return async function runInTransaction(work) {
    const session = await startSession();
    try {
      return await session.withTransaction(() => work(session));
    } catch (error) {
      if (isTransactionUnsupported(error)) {
        throw new TransactionUnavailableError(error);
      }
      throw error;
    } finally {
      await session.endSession();
    }
  };
}

function sendTransactionUnavailable(error, res) {
  if (!(error instanceof TransactionUnavailableError)) return false;
  res.status(503).json({
    error: error.code,
    message: 'This operation requires MongoDB transaction support.',
  });
  return true;
}

module.exports = {
  TransactionUnavailableError,
  createTransactionRunner,
  isTransactionUnsupported,
  sendTransactionUnavailable,
};
