# 获取登录信息
Qiyeweixin.getLoginInfo = (access_token,auth_code) ->
	try
		data = {
			auth_code:auth_code
		}
		response = HTTP.post(
			"https://qyapi.weixin.qq.com/cgi-bin/service/get_login_info?access_token=" + access_token, 
			{
				data: data,
				headers:"Content-Type": "application/json"
			})
		if response.statusCode != 200
			throw response
		return response.data
	catch err
		console.error err
		throw _.extend(new Error("Failed to complete OAuth handshake with suiteAccessTokenGet. " + err), {response: err})
# 获取服务商的token
Qiyeweixin.getProviderToken = (corpid,provider_secret) ->
	try
		data = {
			corpid:corpid,
			provider_secret:provider_secret
		}
		response = HTTP.post(
			"https://qyapi.weixin.qq.com/cgi-bin/service/get_provider_token", 
			{
				data: data,
				headers:"Content-Type": "application/json"
			})
		if response.statusCode != 200
			throw response
		return response.data
	catch err
		console.error err
		throw _.extend(new Error("Failed to complete OAuth handshake with suiteAccessTokenGet. " + err), {response: err})
		
# 获取suite_access_token:OK
Qiyeweixin.getSuiteAccessToken = (suite_id, suite_secret, suite_ticket) ->
	try
		data = {
			suite_id:suite_id,
			suite_secret:suite_secret,
			suite_ticket:suite_ticket
		}
		response = HTTP.post(
			"https://qyapi.weixin.qq.com/cgi-bin/service/get_suite_token", 
			{
				data: data,
				headers:"Content-Type": "application/json"
			})
		if response.statusCode != 200
			throw response
		return response.data
	catch err
		console.error err
		throw _.extend(new Error("Failed to complete OAuth handshake with suiteAccessTokenGet. " + err), {response: err})

# 获取预授权码:OK
Qiyeweixin.getPreAuthCode = (suite_id,suite_access_token) ->
	try
		data = {
			suite_id:suite_id
		}
		response = HTTP.post(
			"https://qyapi.weixin.qq.com/cgi-bin/service/get_pre_auth_code?suite_access_token=" + suite_access_token, 
			{
				data: data,
				headers:"Content-Type": "application/json"
			})
		if response.statusCode != 200
			throw response
		return response.data
	catch err
		console.error err
		throw _.extend(new Error("Failed to complete OAuth handshake with suiteAccessTokenGet. " + err), {response: err})

# 获取企业永久授权码
Qiyeweixin.getPermanentCode = (suite_id,auth_code,suite_access_token) ->
	try
		data = {
			suite_id:suite_id,
			auth_code:auth_code
		}
		response = HTTP.post(
			"https://qyapi.weixin.qq.com/cgi-bin/service/get_permanent_code?suite_access_token=" + suite_access_token, 
			{
				data: data,
				headers:"Content-Type": "application/json"
			})
		if response.statusCode != 200
			throw response
		return response.data
	catch err
		console.error err
		throw _.extend(new Error("Failed to complete OAuth handshake with suiteAccessTokenGet. " + err), {response: err})

# 获取access_token
Qiyeweixin.getCorpToken = (suite_id,auth_corpid,permanent_code,suite_access_token) ->
	try
		data = {
			suite_id:suite_id,
			auth_corpid:auth_corpid,
			permanent_code:permanent_code
		}
		response = HTTP.post(
			"https://qyapi.weixin.qq.com/cgi-bin/service/get_corp_token?suite_access_token=" + suite_access_token, 
			{
				data: data,
				headers:"Content-Type": "application/json"
			})
		if response.statusCode != 200
			throw response
		return response.data
	catch err
		console.error err
		throw _.extend(new Error("Failed to complete OAuth handshake with suiteAccessTokenGet. " + err), {response: err})

# 获取部门列表
Qiyeweixin.getDepartmentList =(access_token)->
	try
		getDepartmentListUrl = "https://qyapi.weixin.qq.com/cgi-bin/department/list?access_token=" + access_token
		response = HTTP.get getDepartmentListUrl
		if response.error_code
			console.error err
			throw response.msg
		if response.data.errcode>0 
			throw response.data.errmsg
		return response.data.department
	catch err
		console.error err
		throw _.extend(new Error("Failed to complete OAuth handshake with getDepartmentList. " + err), {response: err})

# 获取部门下用户列表
Qiyeweixin.getUserList =(access_token,department_id)->
	try
		getUserListUrl = "https://qyapi.weixin.qq.com/cgi-bin/user/list?access_token=" + access_token + "&department_id=" + department_id + "&fetch_child=0"
		response = HTTP.get getUserListUrl
		if response.error_code
			console.error err
			throw response.msg
		if response.data.errcode>0 
			throw response.data.errmsg
		return response.data.userlist
	catch err
		console.error err
		throw _.extend(new Error("Failed to complete OAuth handshake with getUserList. " + err), {response: err})

# 获取管理员列表
Qiyeweixin.getAdminList =(auth_corpid,agentid)->
	try
		o = ServiceConfiguration.configurations.findOne({service: "qiyeweixin"})
		data = {
			auth_corpid:auth_corpid,
			agentid:agentid
		}
		response = HTTP.post(
			"https://qyapi.weixin.qq.com/cgi-bin/service/get_admin_list?suite_access_token=" + o.suite_access_token, 
			{
				data: data,
				headers:"Content-Type": "application/json"
			})
		if response.statusCode != 200
			throw response
		return response.data.admin
	catch err
		console.error err
		throw _.extend(new Error("Failed to complete OAuth handshake with suiteAccessTokenGet. " + err), {response: err})
