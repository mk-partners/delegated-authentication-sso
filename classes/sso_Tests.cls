@isTest
private class sso_Tests {

	static User testUser = [SELECT Id, Username FROM User WHERE UserType = 'Standard' AND IsActive = true LIMIT 1]; 
	
    static testMethod void sso_WebService_UnitTest() {
    	test.startTest();
			String sampleRequest = '<?xml version="1.0" encoding="UTF-8" ?>';
			sampleRequest += '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">';
			sampleRequest += '<soapenv:Body><Authenticate xmlns="urn:authentication.soap.sforce.com">';
			sampleRequest += '<username>'+testUser.userName+'</username>';
			sampleRequest += '<password>myPassword99</password>';
			sampleRequest += '<sourceIp>1.2.3.4</sourceIp>';
			sampleRequest += '</Authenticate></soapenv:Body></soapenv:Envelope>';

			System.RestContext.request = new RestRequest();
			RestContext.request.requestURI = '/sso_WebService/';
			RestContext.request.requestBody = blob.valueOf(sampleRequest);

			System.RestContext.response = new RestResponse();
			sso_WebServices.authenticateSSO();
			sso_WebServices.isNotNull(null);
		test.stopTest();		

    }

	static testMethod void sso_Controller_UnitTest(){
		test.startTest();
			PageReference p = page.sso_Google;
			p.getParameters().put('code','abcdefghijklmnopqrstuvwxyz');

			sso_Controller con = new sso_Controller();
			con.autoLogin();

			con.loginWithGoogle();
			con.googleListenerOnLoad();
		test.stopTest();
	}

	static testMethod void lockedOut_Controller_UnitTest(){
		test.startTest();
			lockedOut_Controller controller = new lockedOut_Controller();
			controller.username = 'me@domain.com';
			controller.submit();
		test.stopTest();
	}

}