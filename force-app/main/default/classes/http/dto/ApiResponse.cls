/** JSON envelope for inbound REST endpoints; outbound raw results use ApiCalloutResult. */
public with sharing class ApiResponse {
  public Boolean success;
  public Object data;
  public ApiError error;
  public String requestId;
}
