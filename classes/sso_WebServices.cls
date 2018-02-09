@RestResource(urlMapping='/sso_WebService/*')
global class sso_WebServices {
//	webserviceSampleURL		https://mkpartners.secure.force.com/services/apexrest/sso_WebService/

	public static String GOOGLE_CLIENT_ID = '';
	public static String GOOGLE_CLIENT_SECRET = '';
	public static String CRYPTO_KEY = '';
	public static String CRYPTO_IV = '';
	static final String SITE_DOMAIN = '';
	public static String siteURL = ''+SITE_DOMAIN+'.force.com';
	public static String salesforceLoginEndpoint = 'https://login.salesforce.com';
	public static String sandboxSuffix = 'dev';
	public static String webserviceURL = 'https://'+SITE_DOMAIN+'.secure.force.com/services/apexrest/sso_WebService/';
	public static String loginURL = 'https://'+SITE_DOMAIN+'.secure.force.com/sso_Login';
	public static String GoogleListenerURL = 'https://'+SITE_DOMAIN+'.secure.force.com/sso_Google';

	@HttpPost
	global static void authenticateSSO(){
        RestRequest req = RestContext.request;
        system.debug(req.requestURI);
		RestResponse res = RestContext.response;
		res.addHeader('Content-Type', 'text/xml; charset=utf-8');

		res.statusCode = authenticate( req.requestBody.toString() );
		String responseBody = '<?xml version="1.0" encoding="UTF-8"?>';
		responseBody += '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">';
		responseBody += '<soapenv:Body><AuthenticateResult xmlns="urn:authentication.soap.sforce.com">';
		responseBody += '<Authenticated>' + string.valueOf(res.statusCode == 200) + '</Authenticated>';
		responseBody += '</AuthenticateResult></soapenv:Body></soapenv:Envelope>';
		res.responseBody = blob.valueOf(responseBody);
		system.debug(res.responseBody.toString());
	}

	public static Integer authenticate(String body){
		String username;
		String password;
//		String sourceIp;
        XmlStreamReader xsr = new XmlStreamReader(body);
        system.debug(body);
		while(xsr.hasNext()) {
			if ( xsr.getEventType() === XmlTag.START_ELEMENT && xsr.getLocalName() != null && xsr.getLocalName() == 'username' ){
				xsr.next();
				username = xsr.getText();
			}
			if ( xsr.getEventType() === XmlTag.START_ELEMENT && xsr.getLocalName() != null && xsr.getLocalName() == 'password' ){
				xsr.next();
				password = xsr.getText();
			}
//			if ( xsr.getEventType() === XmlTag.START_ELEMENT && xsr.getLocalName() != null && xsr.getLocalName() == 'sourceIp' ){
//				xsr.next();
//				sourceIp = xsr.getText();
//			}
			if ( username != null && password != null ){
				break;
			}
			xsr.next();
		}
		List<User> userQuery = queryUserByUsername(username);
		Integer statusCode = 500;
		if ( userQuery.size() == 0 ){
			statusCode = 401;
		} else
		if ( userQuery.size() > 1 ) {
			statusCode = 300;
		} else
		if ( userQuery.size() == 1 && sso_Controller.generateUniqueCode(userQuery[0].LastModifiedDate.formatGMT('yyyy-MM-dd-hh-mm-ss')+':'+userQuery[0].Id)== encodingUtil.urlEncode(password, 'UTF-8') ){
			update userQuery[0];
			statusCode = 200;
		}		
		return statusCode;
	}

	public static List<User> queryUserByUsername(String username){
		String sandboxUsername = username+'.dev';
		return [
			SELECT Id, Username, LastModifiedDate, UserType, IsActive 
			FROM User WHERE IsActive = true AND UserType = 'Standard' 
			AND (username = :username or username = :sandboxUsername ) 
			limit 2
		];
	}

	public static Boolean isNotNull(String s){
		return (s != null && s.trim().length() > 0 );
	}

}