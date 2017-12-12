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
		throw _.extend(new Error("Failed to complete OAuth handshake with suiteAccessTokenGet. " + err), {response: err});


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
		throw _.extend(new Error("Failed to complete OAuth handshake with suiteAccessTokenGet. " + err), {response: err});

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
		throw _.extend(new Error("Failed to complete OAuth handshake with suiteAccessTokenGet. " + err), {response: err});

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
		throw _.extend(new Error("Failed to complete OAuth handshake with suiteAccessTokenGet. " + err), {response: err});

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
		throw _.extend(new Error("Failed to complete OAuth handshake with getDepartmentList. " + err), {response: err});

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
		throw _.extend(new Error("Failed to complete OAuth handshake with getUserList. " + err), {response: err});

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
		throw _.extend(new Error("Failed to complete OAuth handshake with suiteAccessTokenGet. " + err), {response: err});

# 通讯录变更
Qiyeweixin.changeContact = (message)->
	switch message.ChangeType
		when 'create_user'
			console.log "create_user"
			us_doc = {}
			us_doc.name = message.Name
			us_doc.avatar = message.Avatar
			us_doc.userid = message.UserID
			createUser us_doc
			# 调用新增成员方法
		when 'update_user'
			#考虑由于userId也是可修改的，虽然只能修改一次，但是如果修改的是userid,则要先删除，后增加
			up_us = db.users.find({"services.qiyeweixin.id": message.UserID})
			if up_us
				u = up_us
				if message.Name
					u.name = message.Name
				if message.Avatar
					u.avatar = message.Avatar
				if message.NewUserID
					u.services.qiyeweixin.id = message.NewUserID
				u.modified = new Date()
				console.log up_us._id
				db.users.direct.update(up_us._id,{$set:{modified:new Date()}})
				db.users.direct.update(up_us._id,{$set:u})
				 #updateUser(u,up_us)
			# else
			# 	db.users.direct.insert u
			console.log "update_user"
			# 调用修改成员方法
		when 'delete_user'
			console.log "delete_user"
			dt_us = db.users.find({"services.qiyeweixin.id": message.UserID})
			if dt_us
				db.users.direct.remove({"services.qiyeweixin.id": message.UserID})
			# 调用删除成员方法
		when 'create_party'
			console.log "create_party"
			# 调用新增部门方法
		when 'update_party'
			console.log "update_party"
			# 调用修改部门方法
		when 'delete_party'
			console.log "delete_party"
			# 调用删除部门方法
		when 'update_tag'
			console.log "update_tag"
			# 调用修改标签方法

# 同步公司
Qiyeweixin.syncCompany = (access_token,auth_corp_info,auth_info,auth_user_info,permanent_code)->
## 命名规则与钉钉保持一致
# 1.首先要获取用户信息，导入user表，工作区和部门都需要用户这个表数据
	# 组织架构，获取部门列表
	org_data = Qiyeweixin.getDepartmentList access_token
	console.log "=======部门列表======="
	console.log org_data

	# 根据部门获取成员信息
	user_data = []
	org_data.forEach (org)->
		user_data = Qiyeweixin.getUserList access_token,org.id
		# 根据每个成员信息，判断是否新增和修改
		user_data.forEach (u)->
			console.log u.userid
			uq = db.users.find {"services.qiyeweixin.id": u.userid}
			# 如果审批王中存在该用户，则修改用户信息
			console.log uq.count()+"=====查找用户====="
			if uq.count()>0
				console.log "修改用户信息"
				user = uq.fetch()[0]
				modifyUser user,u
			else
				# 创建新用户
				console.log "创建新用户"
				createUser u

# 2.获取工作区信息，导入space表
	# 工作区信息：数据结构见《企业微信接口数据》
	space_data = auth_corp_info
	# 工作区创建者信息：数据结构见《企业微信接口数据》
	space_owner_data = auth_user_info
	owner = db.users.findOne({"services.qiyeweixin.id": space_owner_data.userid})
	# 获取工作区管理员
	console.log owner
	space_admin_data = Qiyeweixin.getAdminList auth_corp_info.corpid,auth_info.agent[0].agentid
	admins = []
	console.log space_admin_data
	space_admin_data.forEach (admin)->
		if admin.auth_type
			admin_user = db.users.findOne({"services.qiyeweixin.id": admin.userid})
			admins.push admin_user._id

	# 工作区id：查找当前工作区是否存在，存在则修改工作区信息，否则新增工作区
	space_id = "qywx-" + space_data.corpid
	sq = db.spaces.find({_id: space_id})
	if sq.count() > 0
	  	# 修改工作区信息:用的情况很少，稍后处理
		db.spaces.update({_id:space_id},{$set:{owner:owner._id,admins:admins,name:auth_corp_info.name}})
		#modifySpace space_data,space_owner_data,sq.fetch()[0],space_id
	else
		# 新建工作区信息
		createSpace space_data,owner,admins,space_id,access_token,permanent_code

	###创建部门###





# 创建工作区
createSpace = (space_data,owner,admins,space_id,access_token,permanent_code)->
	s_doc = {}
	s_doc._id = space_id
	s_doc.name = space_data.corp_name || "未命名"
	s_doc.owner = owner._id
	s_doc.admins = admins
	s_doc.is_deleted = false
	s_doc.created = new Date
	s_doc.created_by = owner._id
	s_doc.modified = new Date
	s_doc.modified_by = owner._id
	s_doc.services = { qiyeweixin:{ corp_id: space_data.corpid, access_token: access_token, permanent_code: permanent_code}}
	space_id = db.spaces.direct.insert(s_doc)



# 修改工作区信息方法
modifySpace = (space_data,admin_data,s,space_id)->
	# 参数说明：命名规则与钉钉保持一致
	# space_data：新工作区信息
	# admin_data：管理员信息
	# s：数据库中存在的旧工作区信息
	# space_id：工作区Id



# 修改用户方法(old)
# updateUser = (u,up_us)->
# 	u = up_us
# 	if u.Name
# 		u.name = message.Name
# 	if message.Avatar
# 		u.avatar = message.Avatar
# 	if message.NewUserID
# 		u.services.qiyeweixin.id = message.NewUserID
# 	if up_us.hasOwnProperty('name') || up_us.hasOwnProperty('avatarURL')
# 		u.modified = new Date()
# 		db.users.direct.update({_id:up_us._id}, {$set: u})


# 修改用户方法(授权企业初始化时候使用的更新用户方法)
modifyUser = (old_user,new_user)->
	doc = {}
	if old_user.name != new_user.name
		doc.name = new_user.name
	if old_user.avatarURL != new_user.avatar
		doc.avatarURL = new_user.avatar
	if old_user.is_deleted
		doc.is_deleted = false
	if doc.hasOwnProperty('name') || doc.hasOwnProperty('avatar') || doc.hasOwnProperty('is_deleted')
		doc.modified = new Date()
		db.users.direct.update old_user._id, {$set: doc}

# 创建用户方法
createUser = (user)->
	console.log "==========创建新用户=============="
	doc = {}
	doc._id = db.users._makeNewID()
	doc.steedos_id = doc._id
	# 由于没有email，所以设置使用
	doc.email = user.userid
	doc.name = user.name
	doc.locale = "zh-cn"
	doc.is_deleted = false
	doc.created = new Date
	doc.modified = new Date
	doc.services = {qiyeweixin:{id: user.userid}}
	doc.avatarURL = user.avatar
	console.log doc
	db.users.direct.insert(doc)
















