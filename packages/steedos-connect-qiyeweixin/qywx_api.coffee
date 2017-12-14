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

# 初始化公司
Qiyeweixin.initCompany = (auth_corp_info,auth_info)->
## 命名规则与钉钉保持一致
	console.log "============企业相关数据==============="
	console.log auth_corp_info
## 初始化，先把工作区中所有的都清空，包括spqce、user、organizations、spqce_user这几个表
	space_id = auth_corp_info.space_id
	# 删除user
	# 根据查询到的space_user数据，删除user表中数据
	delete_users = []
	delete_users = db.space_users.find({space:space_id},fields: {_id:1})
	delete_users.forEach (delete_user)->
		db.users.direct.remove({_id: delete_user._id})
	# 删除space_user
	db.space_users.direct.remove({space:space_id})
	# 删除organization
	db.organizations.direct.remove({space:space_id})
	# 删除spqce
	db.spaces.direct.remove({_id: space_id})

## 新增数据，spqce、user、organizations、spqce_user这几个表
	# 首先找出owner
	admins = []
	space_admin_data = Qiyeweixin.getAdminList auth_corp_info.corpid,auth_info.agent[0].agentid
	space_admin_data.forEach (admin)->
		if admin.auth_type
			admin_user = db.users.findOne({"services.qiyeweixin.id": admin.userid})
			if admin_user
				admins.push admin_user._id
	auth_corp_info.owner = admins[0]

	# space表，初始化新工作区
	createSpace auth_corp_info

	# 组织架构，获取部门列表
	org_data = Qiyeweixin.getDepartmentList auth_corp_info.access_token
	# 根据部门获取成员信息
	org_data.forEach (org)->
		
		user_data = Qiyeweixin.getUserList auth_corp_info.access_token,org.id
		# 循环每个成员
		user_data.forEach (u)->
			# user表，创建新用户
			createUser u
		# organizations表，新增
		createOrganization org_data,space_id

	# 1.首先要获取用户信息，导入user表，工作区和部门都需要用户这个表数据
	# 根据部门获取成员信息
	org_data.forEach (org)->
		user_data = Qiyeweixin.getUserList auth_corp_info.access_token,org.id
		# 循环每个成员
		user_data.forEach (u)->
			# user表，创建新用户
			createUser u
	
	

createOrganization = (org_data,user_data,space_id)->


createSpace = (auth_corp_info)->
	s_doc = {}
	s_doc._id = auth_corp_info.space_id
	s_doc.name = auth_corp_info.corp_name
	s_doc.owner = auth_corp_info.owner
	s_doc.admins = admins
	s_doc.is_deleted = false
	s_doc.created = new Date
	s_doc.created_by = auth_corp_info.owner
	s_doc.modified = new Date
	s_doc.modified_by = auth_corp_info.owner
	s_doc.services = { qiyeweixin:{ corp_id: auth_corp_info.corpid, access_token: auth_corp_info.access_token, permanent_code: auth_corp_info.permanent_code}}
	space_id = db.spaces.direct.insert(s_doc)

# 创建用户方法
createUser = (user)->
	doc = {}
	doc._id = db.users._makeNewID()
	doc.steedos_id = doc._id
	doc.email = user.userid
	doc.name = user.name
	doc.locale = "zh-cn"
	doc.is_deleted = false
	doc.created = new Date
	doc.modified = new Date
	doc.services = {qiyeweixin:{id: user.userid}}
	doc.avatarURL = user.avatar
	db.users.direct.insert(doc)



modifySpace = (old_space,new_space)->
	s_doc = {}
	if old_space.name != new_space.corp_name
		s_doc.name = new_space.corp_name
	if old_space.owner != new_space.owner
		s_doc.owner = new_space.owner
	if old_space.admins.sort().toString() != new_space.admins.sort().toString()
		s_doc.admins = new_space.admins
	if s_doc.hasOwnProperty('name') || s_doc.hasOwnProperty('owner') || s_doc.hasOwnProperty('admins')
		s_doc.modified = new Date
		s_doc.modified_by = new_space.owner
		s_qywx = old_space.services.qiyeweixin
		s_qywx.access_token = new_space.access_token
		s_qywx.permanent_code = new_space.permanent_code
		s_doc['services.qiyeweixin'] = s_qywx
		db.spaces.direct.update(old_space._id, {$set: s_doc})
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















