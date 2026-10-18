/** Outbound HTTP request configuration. Use Named Credentials for authentication. */
public with sharing class ApiRequest {
  /** Relative to the service endpoint owned by ApiHttpClient. */
  public String path;
  /** Legacy absolute endpoint for clients constructed without a base endpoint. */
  public String endpoint;
  public String method = 'GET';
  public String body;
  /** Select a formatter to encode payload instead of supplying a raw body. */
  public Object payload;
  public IApiBodyFormatter formatter;
  public Integer timeoutMillis = 10000;
  public String requestId;
  public Map<String, String> headers = new Map<String, String>();
  public Map<String, String> queryParameters = new Map<String, String>();
}
