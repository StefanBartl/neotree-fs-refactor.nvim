---@meta
-- Type definitions for luassert used by busted
-- This file is only for LuaLS static analysis

---@class Luassert
---@field equals fun(expected: any, actual: any, message?: string)
---@field is_true fun(value: any, message?: string)
---@field is_false fun(value: any, message?: string)
---@field is_nil fun(value: any, message?: string)
---@field is_number fun(value: any, message?: string)
---@field is_table fun(value: any, message?: string)
---@field are table
---@field has table
---@field is table
---@field is_not table

---@type Luassert

assert = {}

