// Run once per target org after deploying ReportConfig__c.
// This seeds org-level and current-user values. Assign the Support Lead profile
// value separately in Setup if its exact profile is not present in the target org.
ReportConfig__c orgSetting = ReportConfig__c.getOrgDefaults();
if (orgSetting == null)
  orgSetting = new ReportConfig__c(SetupOwnerId = UserInfo.getOrganizationId());
orgSetting.MaxRows__c = 200;
upsert orgSetting;

Profile supportLead = [
  SELECT Id
  FROM Profile
  WHERE Name = 'Support Lead'
  LIMIT 1
];
ReportConfig__c profileSetting = ReportConfig__c.getInstance(supportLead.Id);
if (profileSetting == null || profileSetting.SetupOwnerId != supportLead.Id) {
  profileSetting = new ReportConfig__c(SetupOwnerId = supportLead.Id);
}
profileSetting.MaxRows__c = 1000;
upsert profileSetting;

ReportConfig__c userSetting = ReportConfig__c.getInstance(UserInfo.getUserId());
if (userSetting == null || userSetting.SetupOwnerId != UserInfo.getUserId()) {
  userSetting = new ReportConfig__c(SetupOwnerId = UserInfo.getUserId());
}
userSetting.MaxRows__c = 2000;
upsert userSetting;
