parser = Npm.require('xml2json')
WXBizMsgCrypt = Npm.require('wechat-crypto')

config = ServiceConfiguration.configurations.findOne({service: "qiyeweixin"})

newCrypt = new WXBizMsgCrypt(config?.token, config?.encodingAESKey, config?.corpid)
TICKET_EXPIRES_IN = config.ticket_expires_in || 1000 * 60 * 20 #20分钟


# 创建套件使用，验证回调接口可用性
JsonRoutes.add "get", "/api/qiyeweixin/callback", (req, res, next) ->
	console.log "=============企业应用发送来的数据=============="
	console.log req.query.echostr
	result = newCrypt.decrypt req.query.echostr
	res.writeHead 200, {"Content-Type":"text/plain"}
	res.end result.message

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

		# 验证签名
		# if msg_signature!=newCrypt.getSignature(timestamp, nonce, postData)
		# 	res.writeHead 401
		# 	res.end 'Invalid signature'
		# 	return

		result = newCrypt.decrypt jsonPostData?.xml?.Encrypt
		json = parser.toJson result?.message,{object: true}
		message = json?.xml || {}
		console.log "============企业应用发送来的数据============"
		console.log message
		switch message?.InfoType
			when 'suite_ticket'
				SuiteTicket message
				res.writeHead 200, {"Content-Type":"text/plain"}
				res.end result?.message
			# 授权成功：未完成
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

			# 公司变更
			# when 'change_auth'

			# 通讯录变更
			when 'change_contact'
				ChangeContact message.AuthCorpId

# 企业微信免登给用户设置cookies
JsonRoutes.add "get", "/api/qiyeweixin/sso_steedos", (req, res, next) ->
	o = ServiceConfiguration.configurations.findOne({service: "qiyeweixin"})
	# 获取服务商的token
	at = Qiyeweixin.getProviderToken o.corpid,o.provider_secret
	if at&&at.provider_access_token
		loginInfo = Qiyeweixin.getLoginInfo at.provider_access_token,req.query.auth_code
		# user = db.users.findOne {'services.qiyeweixin.id': loginInfo?.user_info?.userid}
		user = db.users.findOne {'_id':'vmGnPPSnxepZeSLKh'}
		if user
			# 验证成功，登录
			authToken = Accounts._generateStampedLoginToken()
			hashedToken = Accounts._hashStampedToken authToken
			Accounts._insertHashedLoginToken user._id,hashedToken
			Setup.setAuthCookies req,res,user._id,authToken.token
			res.writeHead 301, {'Location': '/'}
			res.end 'success'
		else
			res.reply "用户不存在!"
	else
		res.reply "用户不存在!"

# 通讯录变更，更新space表=============未测试
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
			{$set: {'services.qiyeweixin': s_qywx}}
		)
				

# 根据推送过来的临时授权码，获取永久授权码
CreateAuth = (message)->
	o = ServiceConfiguration.configurations.findOne({service: "qiyeweixin"})
	if o
		# 获取企业永久授权码
		r = Qiyeweixin.getPermanentCode message.SuiteId,message.AuthCode,o.suite_access_token
		console.log r
		if r&&r?.permanent_code
			console.log "===========jinru2222222==========="
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
	console.log service
	# 查找是否存在该工作区，存在更新，不存在新增
	space = db.spaces.findOne {"services.qiyeweixin.corp_id": service.corp_id}
	if space
		# 更新工作区，只更新service基本信息
		service.remote_modified = new Date
		service.need_sync = true
		modified = new Date
		db.spaces.direct.update(
			{_id:space._id},
			{$set:{modified:modified,'services.qiyeweixin':service}}
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
		db.spaces.direct.insert doc

# 根据suite_ticket，获取suite_access_token
SuiteTicket = (message)->
	o = ServiceConfiguration.configurations.findOne({service: "qiyeweixin"})
	if o
		r = Qiyeweixin.getSuiteAccessToken o.suite_id,o.suite_secret,message.SuiteTicket
		if r&&r?.suite_access_token
			ServiceConfiguration.configurations.update(o._id,
				{
					$set: {
						"suite_ticket": message.SuiteTicket,
						"suite_access_token": r.suite_access_token
					},
					$currentDate:{
						"modified": true
					}
				})

