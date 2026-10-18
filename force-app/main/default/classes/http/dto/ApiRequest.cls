/** Outbound HTTP request configuration. Use Named Credentials for authentication. */
public with sharing class ApiRequest {
  public String endpoint;
  public String method = 'GET';
  public String body;
  /** Select a codec to encode payload instead of supplying a raw body. */
  public Object payload;
  public IApiBodyCodec codec;
  public Integer timeoutMillis = 10000;
  public String requestId;
  public Map<String, String> headers = new Map<String, String>();
  public Map<String, String> queryParameters = new Map<String, String>();
}
