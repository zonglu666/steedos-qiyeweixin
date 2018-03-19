Cookies = Npm.require("cookies")
parser = Npm.require('xml2json')
WXBizMsgCrypt = Npm.require('wechat-crypto')

config = ServiceConfiguration.configurations.findOne({service: "qiyeweixin"})

if config
	newCrypt = new WXBizMsgCrypt(config?.secret?.token, config?.secret?.encodingAESKey, config?.secret?.corpid)
	TICKET_EXPIRES_IN = config?.secret?.ticket_expires_in || 1000 * 60 * 20 #20分钟

# 工作台首页
JsonRoutes.add "get", "/api/qiyeweixin/mainpage", (req, res, next) ->
	o = ServiceConfiguration.configurations.findOne({service: "qiyeweixin"})
	if o
		redirect_uri = encodeURIComponent Meteor.absoluteUrl('api/qiyeweixin/auth_login')
		authorize_uri = Meteor?.settings?.qiyeweixin?.authorize_uri
		appid = o?.secret?.corpid
		url = authorize_uri+'?appid='+appid+'&redirect_uri='+redirect_uri+'&response_type=code&scope=snsapi_base#wechat_redirect'
		res.writeHead 302, {'Location': url}
		res.end ''

# 网页授权登录
JsonRoutes.add "get", "/api/qiyeweixin/auth_login", (req, res, next) ->
	cookies = new Cookies( req, res );
	userId = cookies.get("X-User-Id")
	authToken = cookies.get("X-Auth-Token")
	# 根据授权码获取用户
	if req?.query?.code
		userInfo = Qiyeweixin.getUserInfo3rd req.query.code
	else
		res.writeHead 200, {'Content-Type': 'text/html'}  
		res.write '<head><meta charset="utf-8"/></head>'
		res.write '<h1>提示 Tips</h1>' 
		res.write '<h2>未从企业微信获取到网页授权码</h2>'
		return res.end ''
	user = db.users.findOne({'services.qiyeweixin.id': userInfo?.UserId})
	if !user
		res.writeHead 200, {'Content-Type': 'text/html'}  
		res.write '<head><meta charset="utf-8"/></head>'
		res.write '<h1>提示 Tips</h1>' 
		res.write '<h2>正在同步企业微信用户数据...</h2>'
		return res.end ''
	# 如果本地已经有cookies
	if userId and authToken
		# 比较本地数据和当前用户是否一致
		if user._id!=userId
			# 不一致，清除信息
			Setup.clearAuthCookies(req, res)
			hashedToken = Accounts._hashLoginToken(authToken)
			Accounts.destroyToken(userId, hashedToken)
		else
			res.writeHead 302, {'Location': '/'}
			return res.end ''
	# 验证成功，登录
	authToken = Accounts._generateStampedLoginToken()
	hashedToken = Accounts._hashStampedToken authToken
	Accounts._insertHashedLoginToken user._id,hashedToken
	Setup.setAuthCookies req,res,user._id,authToken.token
	res.writeHead 302, {'Location': '/'}
	return res.end ''

# 从企业微信端单点登录:从浏览器后台管理页面“前往服务商后台”进入的网址
JsonRoutes.add "get", "/api/qiyeweixin/sso_steedos", (req, res, next) ->
	o = ServiceConfiguration.configurations.findOne({service: "qiyeweixin"})
	# 获取服务商的token
	at = Qiyeweixin.getProviderToken o?.secret?.corpid,o?.secret?.provider_secret
	if at&&at.provider_access_token
		loginInfo = Qiyeweixin.getLoginInfo at.provider_access_token,req.query.auth_code
		if loginInfo?.user_info?.userid
			user = db.users.findOne({'services.qiyeweixin.id': loginInfo.user_info.userid})
			if user
				# 验证成功，登录
				authToken = Accounts._generateStampedLoginToken()
				hashedToken = Accounts._hashStampedToken authToken
				Accounts._insertHashedLoginToken user._id,hashedToken
				Setup.setAuthCookies req,res,user._id,authToken.token
				res.writeHead 302, {'Location': '/'}
				res.end 'success'
			else
				res.writeHead 200, {'Content-Type': 'text/html'}  
				res.write '<head><meta charset="utf-8"/></head>'
				res.write '<h1>提示 Tips</h1>' 
				res.write '<h2>正在同步企业微信用户数据...</h2>'
				res.end ''
		else
			res.writeHead 200, {'Content-Type': 'text/html'}  
			res.write '<head><meta charset="utf-8"/></head>'
			res.write '<h1>提示 Tips</h1>' 
			res.write '<h2>未从企业微信获取到用户信息！</h2>'
			res.end ''
	else
		res.writeHead 200, {'Content-Type': 'text/html'}  
		res.write '<head><meta charset="utf-8"/></head>'
		res.write '<h1>提示 Tips</h1>' 
		res.write '<h2>未从企业微信获取到服务商的Token</h2>'
		res.end ''

# 创建套件使用，验证第三方回调协议可用性
JsonRoutes.add "get", "/api/qiyeweixin/callback", (req, res, next) ->
	result = newCrypt.decrypt req.query.echostr
	res.writeHead 200, {"Content-Type":"text/plain"}
	res.end result.message

# 第三方回调协议
JsonRoutes.add "post", "/api/qiyeweixin/callback", (req, res, next) ->
	postData = ''
	msg_signature = req.query.msg_signature
	timestamp = req.query.timestamp
	nonce = req.query.nonce
	# 解密
	# 	# 数据块接收中
	req.setEncoding 'utf8'

	req.on "data",(postDataChunk)->
		postData += postDataChunk

	req.on 'end',Meteor.bindEnvironment ()->
		jsonPostData = {}
		jsonPostData = parser.toJson postData,{object: true} || {}

		result = newCrypt.decrypt jsonPostData?.xml?.Encrypt
		json = parser.toJson result?.message,{object: true}
		message = json?.xml || {}

		# 第三方回调协议
		switch message?.InfoType
			# 十分钟一次发送access_token
			when 'suite_ticket'
				SuiteTicket message
				res.writeHead 200, {"Content-Type":"text/plain"}
				res.end result?.message
			# 授权成功
			when 'create_auth'
				# 必须在1秒内响应，保证用户体验
				res.writeHead 200, {"Content-Type":"text/plain"}
				res.end "success"
				CreateAuth message
			
			# 取消授权
			when 'cancel_auth'
				res.writeHead 200, {"Content-Type":"text/plain"}
				res.end result?.message
				CancelAuth message

			# 授权变更
			when 'change_auth'
				ChangeContact message.AuthCorpId
				
			# 通讯录变更
			when 'change_contact'
				ChangeContact message.AuthCorpId


# 通讯录变更，更新space表=============
ChangeContact = (corp_id)->
	space = db.spaces.findOne({'services.qiyeweixin.corp_id': corp_id})
	if space
		s_qywx = space.services.qiyeweixin
		s_qywx.remote_modified = new Date
		s_qywx.need_sync = true
		db.spaces.direct.update(
			{_id: space._id},
			{
				$set: {'services.qiyeweixin': s_qywx}
			})

# 取消授权，更新space表=============OK
CancelAuth = (message)->
	corp_id = message.AuthCorpId
	space = db.spaces.findOne({'services.qiyeweixin.corp_id': corp_id})
	if space
		s_qywx = space.services.qiyeweixin
		s_qywx.permanent_code = undefined
		s_qywx.need_sync = false
		db.spaces.direct.update(
			{_id: space._id},
			{$set: {
				is_deleted:true,
				'services.qiyeweixin': s_qywx
				}
			}
		)
				

# 根据推送过来的临时授权码，获取永久授权码
CreateAuth = (message)->
	o = ServiceConfiguration.configurations.findOne({service: "qiyeweixin"})
	if o
		# 获取企业永久授权码
		r = Qiyeweixin.getPermanentCode message?.SuiteId,message?.AuthCode,o?.secret?.suite_access_token
		if r&&r?.permanent_code
			# 永久授权码
			permanent_code = r.permanent_code
			# 授权企业信息
			auth_corp_info = r.auth_corp_info
			# 授权应用信息
			auth_info = r.auth_info
			# 授权管理员信息
			auth_user_info = r.auth_user_info
			service = {}
			service.corp_id = auth_corp_info.corpid
			service.permanent_code = permanent_code
			service.auth_user_id = auth_user_info.userid
			service.agentid = auth_info.agent[0].agentid
			initSpace service,auth_corp_info.corp_name

initSpace = (service,name)->
	# 查找是否存在该工作区，存在更新，不存在新增
	space = db.spaces.findOne {"services.qiyeweixin.corp_id": service.corp_id}
	if space
		# 更新工作区，只更新service基本信息
		service.remote_modified = new Date
		service.need_sync = true
		modified = new Date
		newSpace = db.spaces.direct.update(
			{_id:space._id},
			{$set:{
				modified:modified,
				name:name,
				is_deleted:false,
				'services.qiyeweixin':service
				}
			}
		)
	else
		# 新增工作区，只新增service基本信息
		doc = {}
		doc._id = 'qywx-' + service.corp_id
		doc.name = name
		doc.is_deleted = false
		doc.created = new Date
		service.need_sync = true
		service.remote_modified = new Date
		doc.services = {qiyeweixin:service}
		newSpace = db.spaces.direct.insert doc

	newSpace = db.spaces.findOne({"services.qiyeweixin.corp_id": service.corp_id})
	if newSpace
		Qiyeweixin.syncCompany newSpace

# 根据suite_ticket，获取suite_access_token
SuiteTicket = (message)->
	o = ServiceConfiguration.configurations.findOne({service: "qiyeweixin"})
	if o
		r = Qiyeweixin.getSuiteAccessToken o?.secret?.suite_id,o?.secret?.suite_secret,message.SuiteTicket
		if r&&r?.suite_access_token
			ServiceConfiguration.configurations.update(o._id,
				{
					$set: {
						"secret.suite_ticket": message.SuiteTicket,
						"secret.suite_access_token": r.suite_access_token
					},
					$currentDate:{
						"modified": true
					}
				})