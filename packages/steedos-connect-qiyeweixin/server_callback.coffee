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
ChangeContact = (message)->
	corp_id = message.AuthCorpId
	space = db.spaces.findOne({'services.qiyeweixin.corp_id': corp_id})
	if space
		s_qywx = space.services.qiyeweixin
		s_qywx.romote_modified = new Date
		db.spaces.direct.update(
			{_id: space._id},
			{
				$set: {'services.qiyeweixin': s_qywx}
			})

# 取消授权，更新space表=============OK
CancelAuth = (message)->
	console.log "=========取消授权========="
	corp_id = message.AuthCorpId
	space = db.spaces.findOne({'services.qiyeweixin.corp_id': corp_id})
	if space
		s_qywx = space.services.qiyeweixin
		s_qywx.permanent_code = undefined
		s_qywx.remote_modified = undefined
		db.spaces.direct.update(
			{_id: space._id},
			{$set: {'services.qiyeweixin': s_qywx}},
			{$currentDate:{modified: true}}
		)
				

# 根据推送过来的临时授权码，获取永久授权码
CreateAuth = (message)->
	o = ServiceConfiguration.configurations.findOne({service: "qiyeweixin"})
	if o
		# 获取企业永久授权码
		r = Qiyeweixin.getPermanentCode message.SuiteId,message.AuthCode,o.suite_access_token
		if r&&r?.permanent_code
			# 永久授权码
			permanent_code = r.permanent_code
			# 授权企业信息
			auth_corp_info = r.auth_corp_info
			# 授权应用信息
			auth_info = r.auth_info
			# 授权管理员信息
			auth_user_info = r.auth_user_info
			# 根据永久授权码获取access_token
			at = Qiyeweixin.getCorpToken o.suite_id,auth_corp_info.corpid,permanent_code,o.suite_access_token
			# 当下授权的access_token
			if at&&at.access_token
				services = {}
				services.corp_id = auth_corp_info.corpid
				services.access_token = at.access_token
				services.permanent_code = permanent_code
				services.auth_user_id = auth_user_info.userid
				services.agentid = auth_info.agent[0].agentid
				initCompany services,auth_corp_info.corp_name

initCompany = (services,name)->
	console.log services
	# 查找是否存在该工作区，存在更新，不存在新增
	space = db.spaces.findOne {"services.qiyeweixin.corp_id": services.corp_id}
	if space
		console.log "更新"
		# 更新工作区，只更新services基本信息
		services.remote_modified = new Date
		modified = new Date
		db.spaces.direct.update(
			{_id:space._id},
			{$set:{modified:modified,'services.qiyeweixin':services}}
		)
	else
		# 新增工作区，只新增services基本信息
		console.log "新增"
		s_doc = {}
		s_doc._id = 'qywx-' + services.corp_id
		s_doc.name = name
		s_doc.is_deleted = false
		s_doc.created = new Date
		s_doc.modified = new Date
		services.sync_modified = new Date
		services.remote_modified = new Date
		s_doc.services = {qiyeweixin:services}
		db.spaces.direct.insert s_doc

# 根据suite_ticket，获取AccessToken
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

