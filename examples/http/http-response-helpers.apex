// Local response objects only. Each write demonstrates an alternative outcome.
Object data = new List<String>{ 'first', 'second' };
String requestId = 'example-request';
ApiWriter.success(new RestResponse(), data, requestId); // 200
ApiWriter.created(new RestResponse(), data, requestId); // 201
ApiWriter.accepted(new RestResponse(), data, requestId); // 202
ApiWriter.noContent(new RestResponse()); // 204
ApiWriter.badRequest(new RestResponse(), 'Invalid input.', requestId); // 400
ApiWriter.unauthorized(
  new RestResponse(),
  'Authentication required.',
  requestId
); // 401
ApiWriter.forbidden(new RestResponse(), 'Access denied.', requestId); // 403
ApiWriter.notFound(new RestResponse(), 'Resource not found.', requestId); // 404
ApiWriter.conflict(new RestResponse(), 'Refresh the resource.', requestId); // 409
ApiWriter.serviceUnavailable(new RestResponse(), 'Try again later.', requestId); // 503
ApiWriter.internalError(new RestResponse(), requestId); // Safe 500
ApiWriter.failed(
  new RestResponse(),
  412,
  new ApiError('STALE_VERSION', 'Refresh the resource.'),
  requestId
);

// Original explicit-status success overload remains available.
ApiWriter.success(new RestResponse(), 206, data, requestId);
Assert.isTrue(ApiWriter.supports(206));
Assert.isFalse(ApiWriter.supports(429)); // Apex REST has a limited status set.

// Envelope factories do not write HTTP status or mutate RestContext.
ApiResponse success = ApiResponseFactory.success(data, requestId);
ApiResponse failed = ApiResponseFactory.failed(
  'INVALID_INPUT',
  'Invalid input.',
  requestId
);
ApiResponse internal = ApiResponseFactory.internalError(requestId);
ApiWriter.write(new RestResponse(), 200, success);
ApiWriter.write(new RestResponse(), 400, failed);
ApiWriter.write(new RestResponse(), 500, internal);

// 304 is bodyless and uses a failure envelope because it is not a 2xx status.
ApiWriter.write(
  new RestResponse(),
  304,
  ApiResponseFactory.failed('NOT_MODIFIED', 'Resource unchanged.', requestId)
);
