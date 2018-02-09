public class sso_Controller {

	public sso_Controller(){
		if ( apexPages.currentPage().getHeaders() != null && apexPages.currentPage().getHeaders().containsKey('X-Salesforce-SIP') ){
			system.debug(apexPages.currentPage().getHeaders().get('X-Salesforce-SIP'));
		}
	}

	public PageReference autoLogin(){
		return loginWithGoogle();
	}

	public PageReference loginWithGoogle(){
		PageReference p = new PageReference('https://accounts.google.com/o/oauth2/auth');
		//Determines if the Google Authorization Server returns an authorization code (code), or an opaque access token (token)
		p.getParameters().put('response_type','code');	
		p.getParameters().put('redirect_uri',sso_Webservices.GoogleListenerURL);
		p.getParameters().put('client_id',sso_Webservices.GOOGLE_CLIENT_ID);
		p.getParameters().put('approval_prompt','auto');
		p.getParameters().put('scope','https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/userinfo.profile');
		/* This optional parameter indicates any state which may be useful to your application upon receipt of the response. 
			The Google Authorization Server roundtrips this parameter, so your application receives the same value it sent. 
			Possible uses include redirecting the user to the correct resource in your site, nonces, and cross-site-request-forgery mitigations.
		*/
		p.getParameters().put('state',userInfo.getOrganizationId());	
		p.getParameters().put('access_type','online');
		return p;
	}

	public PageReference googleListenerOnLoad(){
		String body = '';
		Map<String,String> paramMap = apexPages.currentPage().getParameters();
		if ( paramMap.containsKey('code') ){
			body += 'code='+encodingUtil.urlEncode(paramMap.get('code'),'UTF-8')+'&';
		}
		body += 'client_id=' + encodingUtil.urlEncode(sso_Webservices.GOOGLE_CLIENT_ID,'UTF-8') + '&';
		body += 'client_secret=' + encodingUtil.urlEncode(sso_Webservices.GOOGLE_CLIENT_SECRET,'UTF-8') + '&';
		body += 'scope=&';
		body += 'redirect_uri='+encodingUtil.urlEncode(sso_Webservices.GoogleListenerURL,'UTF-8')+'&';
		body += 'grant_type=authorization_code';
		httpResponse googleAuth = doCallout('https://accounts.google.com/o/oauth2/token','POST',body,'GoogleToken');		
		String username;
		if ( googleAuth.getStatusCode() == 200 ){
			String accessToken;
			jsonParser parser = json.createParser(googleAuth.getBody());
			while ( parser.nextToken() != null ){
				if ( parser.getCurrentToken() == JSONToken.FIELD_NAME && parser.getText() != null && parser.getText() == 'access_token' ){
					parser.nextToken();
					accessToken = parser.getText();
				}
			}
			if ( accessToken != null ){
				googleAuth = doCallOut('https://www.googleapis.com/oauth2/v1/userinfo?access_token='+accessToken,'GET',null,'GoogleToken');
				parser = json.createParser(googleAuth.getBody());
				while ( parser.nextToken() != null ){
					if ( parser.getCurrentToken() == JSONToken.FIELD_NAME && parser.getText() != null && parser.getText() == 'email' ){
						parser.nextToken();
						username = parser.getText();
					}
				}
			}
		}
		return generateFinalEndpoint(username);
	}

	public static PageReference generateFinalEndpoint(String username){
		PageReference finalEndpoint = new PageReference(sso_Webservices.salesforceLoginEndpoint);
		List<User> userQuery = sso_WebServices.queryUserByUsername(username);
		if ( userQuery.size() == 1 ){
			String salesforceAuthBody = 'pw='+sso_Controller.generateUniqueCode(userQuery[0].LastModifiedDate.formatGMT('yyyy-MM-dd-hh-mm-ss')+':'+userQuery[0].Id) + '&un='+encodingUtil.urlEncode(userQuery[0].UserName,'UTF-8');
			httpResponse salesforceAuth = doCallout(sso_Webservices.salesforceLoginEndpoint,'POST',salesforceAuthBody,null);
			if ( salesforceAuth.getStatusCode() == 302 && salesforceAuth.getHeader('Location') != null ){
				finalEndpoint = new PageReference( salesforceAuth.getHeader('Location') );
			}
		}
		system.debug(finalEndpoint);
		return finalEndpoint;
	}

	public static String generateUniqueCode(String i){
		String key = sso_Webservices.CRYPTO_KEY;
		String init = sso_Webservices.CRYPTO_IV;
		Blob b = crypto.encrypt('AES256', encodingUtil.base64Decode(key), encodingUtil.base64Decode(init), blob.valueOf(i.trim()) );
		String s = encodingUtil.base64Encode(b);
		String f = encodingUtil.urlEncode(s,'UTF-8');
		return f;
	}

	public static httpResponse doCallOut(String endpoint, String method, String body, String callOutType){
		Http h = new Http();
		HttpRequest req = new HttpRequest();
		req.setEndpoint(endpoint);
		req.setMethod(method);
		req.setCompressed(false);
		if ( callOutType == 'GoogleAuth' ){
			req.setHeader('Content-Type','text/XML');
		} else {
			req.setHeader('Content-Type','application/x-www-form-urlencoded');
		}
		req.setHeader('Encoding','iso-8859-1');
		if( body != null ){
			req.setBody(body);
			req.setHeader('Content-length',string.valueOf(body.length()));
			system.debug(body);
		}
		HttpResponse res = new HttpResponse();
		if ( test.isRunningTest() ){
			res.setStatusCode(200);
			res.setBody('{"access_token":"sampleToken"}');
		} else {
			res = h.send(req);
		}
		return res;
	}


}