

### 企业微信

### 1.1. 相关的推送事件
### 1.1.1. 推送ticket事件
- 企业微信每10分钟推送ticket。
- 审批王后台接受到ticket后，调用接口获取tocken。
- 将ticket和tocken保存在meteor自带的配置表中。
### 1.1.2. 授权应用事件
- 授权方在企业微信的应用管理中，授权审批王应用。
- 企业微信会立即推送create_auth事件，并传递临时授权码。
- 审批王后端根据临时授权码获取永久授权码。
- 使用永久授权码，获取授权企业信息和授权应用信息。
- 根据相关信息，初始化工作区，并将space表中的service下'need_sync'(是否同步)字段改为true。
### 1.1.3. 取消授权事件
- 授权方在企业微信的应用管理中，取消授权审批王应用。
- 企业微信会立即推送cancel_auth事件。
- 审批王将对应space表中的service下'need_sync'(是否同步)字段改为false。
### 1.1.4. 通讯录变更事件
- 授权方在企业微信中修改了通讯录信息。
- 企业微信会立即推送change_contact事件。
- 审批王将对应space表中的service下'need_sync'(是否同步)字段改为true。
### 1.1.4. 授权变更事件
- 授权方在企业微信中修改了审批完该应用的授权范围。
- 企业微信会立即推送change_auth事件。
- 审批王将对应space表中的service下'need_sync'(是否同步)字段改为true。

### 1.2. 同步规则
- 授权成功事件，企业微信发送推送给审批王后端。
- 审批王会根据授权码获取到授权企业的详细信息。
- 查找当前系统是否存在该企业的工作区，存在则修改相应名称，不存在则新增一条工作区记录。
- 设置该工作区的service下'need_sync'(是否同步)字段为true。
- 审批王每10分钟查找数据库中spaces表，如果'need_sync'(是否同步)字段为true，则从企业微信全量获取通讯录并同步到审批王数据库中。

### 1.2.1. users表主要字段规则
- _id：创建新的id
- service.qiyeweixin.id：企业微信UserId

### 1.2.2. spaces表主要字段规则
- _id：qywx-企业CropId
- name:授权企业简称
- admins：调用企业微信接口，获取当前企业下的所有超级管理员，并从user表中查找对应。
- owner：管理员中的第一个成员默认为创建者。

### 1.2.3. organizations表主要字段规则
- _id：qywx-企业CropId-企业微信DepartmentId
- space:qywx-企业CropId
- name:部门名称

### 1.2.4. space_users表主要字段规则
- _id：qywx-企业CropId-企业微信UserId
- space:qywx-企业CropId
- organizations:所属部门
- organization：organizations的第一个值