local function empty()
end
local function self_iter(any,done)
 if done~=true then
  return true,any
 end
end
---@generic T: any, V
---@param any T
---@return fun(any:V[],i?:integer):integer,V
---@return T?
---@return integer?
local pipairs=function(any)
 if any==nil then
  return empty
 end
 if type(any)=="table" then
  return ipairs(any)
 end
 return self_iter,any
end
---@param any any
---@return string
local function qoute_tostring(any)
 if type(any)=="string" then
  return '"'..any..'"'
 end
 return tostring(any)
end
---@param union valitab[]
---@return string
local function union_tostring(union)
 local ret={}
 for i,v in ipairs(union) do
  if type(v)=="string" then
   ret[i]=v
  else
   ret[i]="...others"
   break
  end
 end
 return "["..table.concat(ret,",").."]"
end
---@param enum table<any,true>[]
---@return string
local function enum_tostring(enum)
 local ret={}
 for k in pairs(enum) do
  if type(k)=="string" then
   ret[#ret+1]=qoute_tostring(k)
  else
   ret[#ret+1]="...others"
   break
  end
 end
 return "["..table.concat(ret,",").."]"
end
---@param valitab valitab
---@return string
local function valitab_tostring(valitab)
 if valitab=="string" then
  return valitab
 end
 local t=type(valitab)
 if t=="string" then
  return valitab
 end
 if t~="table" then
  return "Wrong valitab"
 end
 if valitab[1] then
  return union_tostring(valitab)
 end
 return enum_tostring(valitab)
end
---@param main string
---@param sub any
---@return string
local function index_connect(main,sub)
 if type(sub)=="string" then
  if string.find(sub,"^[_A-Za-z][_A-Za-z0-9]*$") then
   return main.."."..sub
  end
  return main..'["'..sub..'"]'
 end
 return main.."["..tostring(sub).."]"
end
---@param name string
---@param valitab valitab
---@param got any
local function terror(name,valitab,got)
 if name==nil then name="Some Value" end
 error(
  [[Type Error: ]]..name
  ..[[, expect ]]..valitab_tostring(valitab)
  ..[[, got ]]..qoute_tostring(got)
 )
end
---@enum (key) special_type
local special_type={
 integer=true,["true"]=true,["false"]=true,float=true,
}
local special={}
---@param val any
function special.integer(val)
 return math.floor(val)==val
end
---@param val any
function special.float(val)
 return math.floor(val)~=val
end
---@param val any
special["true"]=function(val)
 return val==true
end
---@param val any
special["false"]=function(val)
 return val==false
end
---@param val any
---@param expect special_type
---@param name string
function special.type(val,expect,name)
 local ok=special[expect](val,name)
 if ok==false then
  terror(name,expect,val)
 end
 return true
end
local M={}
---@param val any
---@param expect vtype
---@param name string
---@return boolean
function M.type(val,expect,name)
 if special_type[expect] then
  return special.type(val,expect,name)
 end
 local got=type(val)
 if got~=expect then
  terror(name,expect,val)
 end
 return true
end
---@param val any
---@param data valitab
---@param name string
---@return boolean
function M.union(val,data,name)
 for _,v in pipairs(data) do
  if pcall(M.vali,val,v,name) then
   return true
  end
 end
 terror(name,data,val)
 return false
end
---@param val any
---@param data valitab
---@param name string
---@return boolean
function M.punion(val,data,name)
 for _,v in pipairs(data) do
  M.vali(val,v,name)
 end
 return true
end
---@param val table
---@param data valitab
---@param name string
---@return boolean
function M.list(val,data,name)
 for i,v in ipairs(val) do
  M.vali(v,data,index_connect(name,i))
 end
 return true
end
---@param val table
---@param data valitab.dict.data
---@param name string
---@return boolean
function M.dict(val,data,name)
 local vk,vv=data.k,data.v
 for k,v in pairs(val) do
  local n=index_connect(name,k)
  M.vali(k,vk,n..":key")
  M.vali(v,vv,n)
 end
 return true
end
---@param val any
---@param data valitab.enum.data
---@param name string
---@return boolean
function M.enum(val,data,name)
 if val==nil then
  return true
 end
 if data[val]==nil then
  terror(name,data,val)
 end
 return true
end
---@param val any
---@param data valitab.enum.data
---@param name string
---@return boolean
function M.penum(val,data,name)
 if val==nil then
  terror(name,data,val)
 end
 if data[val]==nil then
  terror(name,data,val)
 end
 return true
end
---@param val table
---@param vali table
---@param name string
function M.recur(val,vali,name)
 ---@cast vali -string,-function
 for k,v in pairs(vali) do
  M.vali(val[k],v,index_connect(name,k))
 end
 return true
end
---@alias valitab.func.data fun(x):boolean,string
---@alias valitab.dict.data {k:valitab,v:valitab}
---@alias valitab.enum.data table<any,true>
---@class valitab.attr
---@field attr "dict"|"list"|"recur"|"punion"|"union"|"enum"|"penum"|"type"
---@field data valitab|valitab.dict.data|valitab.enum.data|nil
local valid_attr={
 dict=true,
 enum=true,
 penum=true,
 list=true,
 recur=true,
 type=true,
 punion=true,
 union=true,
 func=true,
}
local tbl_attr={
 dict=true,
 list=true,
 recur=true,
}
---@param val any
---@param vali valitab.func.data
---@param name string
---@return boolean
function M.func(val,vali,name)
 local ret,expect=vali(val)
 if ret==false then
  terror(name,expect,val)
 end
 return true
end
---@alias vtype type|special_type
---@alias valitab vtype|vtype[]|valitab.attr|valitab.enum.data|valitab.func.data|valitab.func.data[]
---@param val any
---@param vali valitab
---@param name string
---@return boolean
function M.vali(val,vali,name)
 local t=type(vali)
 if t=="string" then
  return M.type(val,vali,name)
 elseif t=="function" then
  return M.func(val,vali,name)
 elseif t=="table" then
  local attr=vali.attr
  if tbl_attr[attr] then
   M.type(val,"table",name)
  end
  if attr~=nil and valid_attr[attr] then
   return M[attr](val,vali.data,name)
  end
  return M.recur(val,vali,name)
 end
 return false
end
function M.mk(attr,data)
 return {
  attr=attr,
  data=data,
 }
end
function M.mk_union(...)
 return M.mk("union",{...})
end
function M.mk_dict(k,v)
 return M.mk("dict",{k=k,v=v})
end
function M.mk_punion(...)
 return M.mk("union",{...})
end
local mk_enum_tab=function (...)
 local enum={}
 local len=select("#",...)
 for i=1,len do
  enum[select(i,...)]=true
 end
 return enum
end
function M.mk_enum(...)
 return M.mk("enum",mk_enum_tab(...))
end
function M.mk_penum(...)
 return M.mk("penum",mk_enum_tab(...))
end
function M.mk_square(dot)
 return {
  attr="list",
  data={
   attr="list",
   data=dot,
  },
 }
end
function M.mk_plist(any)
 return {
  attr="union",
  data={
   any,
   {
    attr="list",
    data=any,
   },
  },
 }
end
return M
