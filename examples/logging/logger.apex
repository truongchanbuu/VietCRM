// Adapt schema names and grant event create permission before running in a development org.
LoggerService logger = LoggerService.fromSource('LoggerExample');
logger.info('Example started');
logger.error('Example diagnostic', 'EXAMPLE', UserInfo.getUserId());
LogFlushResult report = LoggerService.flushWithResult();
System.debug('Accepted requests: ' + report.acceptedCount);
System.debug('Rejected requests: ' + report.rejectedCount);
