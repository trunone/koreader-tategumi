local IME = require("ui/data/keyboardlayouts/generic_ime")
local logger = require("logger")
local util = require("util")
local _ = require("gettext")

-- Start with the English keyboard layout
local boshiamy_keyboard = dofile("frontend/ui/data/keyboardlayouts/en_keyboard.lua")
local SETTING_NAME = "keyboard_chinese_boshiamy_settings"

-- Build key_map mapping both lowercase and uppercase letters (A-Z) and punctuation to internal codes
local key_map = {}
local keys_string = "abcdefghijklmnopqrstuvwxyz,.'[]"
for i = 1, #keys_string do
    local c = keys_string:sub(i, i)
    key_map[c] = c
    key_map[c:upper()] = c
end

local code_map = dofile("frontend/ui/data/keyboardlayouts/zh_boshiamy_data.lua")
local settings = G_reader_settings:readSetting(SETTING_NAME, {show_candi=true})
local ime = IME:new {
    code_map = code_map,
    key_map = key_map,
    exact_match = true, -- Boshiamy matches exact input code for candidates
    partial_separators = {" "},
    show_candi_callback = function()
        return settings.show_candi
    end,
    switch_char = "→",
    switch_char_prev = "←",
}

-- Override getHintChars to display typed composition code / roots (組字字根)
ime.getHintChars = function(self)
    self.hint_char_count = 0
    self.on_stage_char_count = 0
    local hint_chars = ""
    local imex = self:getImex() or { code = "", candi = {}, index = 1, char = "" }

    if imex.code and #imex.code > 0 then
        -- Display selected character candidate on stage if available
        if imex.char and imex.char ~= "" then
            hint_chars = hint_chars .. imex.char
            self.on_stage_char_count = self.on_stage_char_count + #util.splitToChars(imex.char)
        end

        -- Display composition roots (uppercase) in parentheses/brackets e.g. " (ABC)"
        local upper_code = imex.code:upper()
        hint_chars = hint_chars .. " (" .. upper_code .. ")"
        self.hint_char_count = self.hint_char_count + #upper_code + 3

        -- Display other candidates if candidate list is available and enabled
        if self:show_candi_callback() and #imex.candi > 1 then
            hint_chars = hint_chars .. "["
            local pos = (imex.index % #imex.candi)
            if pos == 0 then pos = #imex.candi end
            for i = 1, math.min(#imex.candi - 1, 5) do
                pos = pos == #imex.candi and 1 or pos + 1
                local candi_char = imex.candi[pos]
                hint_chars = hint_chars .. candi_char
                self.hint_char_count = self.hint_char_count + #util.splitToChars(candi_char)
            end
            if #imex.candi > 6 then
                hint_chars = hint_chars .. "…"
                self.hint_char_count = self.hint_char_count + 1
            end
            hint_chars = hint_chars .. "]"
            self.hint_char_count = self.hint_char_count + 2
        end
    end

    logger.dbg("zh_boshiamy_kbd: got hint chars:", hint_chars, "with count", self.hint_char_count, "on stage count", self.on_stage_char_count)
    return hint_chars
end

-- Make letter keys fixedly display uppercase letters (A-Z) on layers 1 and 2
-- Row 2: Q W E R T Y U I O P
local row2_keys = { "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P" }
for idx, char in ipairs(row2_keys) do
    local key_entry = boshiamy_keyboard.keys[2][idx]
    key_entry[1] = char
    key_entry[2] = char
end

-- Row 3: A S D F G H J K L
local row3_keys = { "A", "S", "D", "F", "G", "H", "J", "K", "L" }
for idx, char in ipairs(row3_keys) do
    local key_entry = boshiamy_keyboard.keys[3][idx]
    key_entry[1] = char
    key_entry[2] = char
end

-- Row 4: Z X C V B N M
local row4_keys = { "Z", "X", "C", "V", "B", "N", "M" }
for idx, char in ipairs(row4_keys) do
    local key_entry = boshiamy_keyboard.keys[4][idx + 1] -- offset by 1 for shift key
    key_entry[1] = char
    key_entry[2] = char
end

-- Customize punctuation key popups
boshiamy_keyboard.keys[3][10][2] = {
    "，",
    north = "；",
    alt_label = "；",
    northeast = "（",
    northwest = "“",
    east = "《",
    west = "？",
    south = ",",
    southeast = "【",
    southwest = "「",
    "{",
    "[",
    ";"
}

boshiamy_keyboard.keys[5][3][2] = {
    "。",
    north = "：",
    alt_label = "：",
    northeast = "）",
    northwest = "”",
    east = "…",
    west = "！",
    south = ".",
    southeast = "】",
    southwest = "」",
    "}",
    "]",
    ":"
}

local genMenuItems = function(self)
    return {
        {
            text = _("Show character candidates"),
            checked_func = function()
                return settings.show_candi
            end,
            callback = function()
                settings.show_candi = not settings.show_candi
                G_reader_settings:saveSetting(SETTING_NAME, settings)
            end
        }
    }
end

local wrappedAddChars = function(inputbox, char)
    ime:wrappedAddChars(inputbox, char)
end

local wrappedRightChar = function(inputbox)
    if ime:hasCandidates() then
        ime:wrappedAddChars(inputbox, "→")
    else
        ime:separate(inputbox)
        inputbox.rightChar:raw_method_call()
    end
end

local wrappedLeftChar = function(inputbox)
    if ime:hasCandidates() then
        ime:wrappedAddChars(inputbox, "←")
    else
        ime:separate(inputbox)
        inputbox.leftChar:raw_method_call()
    end
end

local function separate(inputbox)
    ime:separate(inputbox)
end

local function wrappedDelChar(inputbox)
    ime:wrappedDelChar(inputbox)
end

local function clear_stack()
    ime:clear_stack()
end

local wrapInputBox = function(inputbox)
    if inputbox._boshiamy_wrapped == nil then
        inputbox._boshiamy_wrapped = true
        local wrappers = {}

        -- Wrap all navigation and non-single-character-input keys to finish input status
        table.insert(wrappers, util.wrapMethod(inputbox, "delChar", wrappedDelChar, nil))
        table.insert(wrappers, util.wrapMethod(inputbox, "delToStartOfLine", nil, clear_stack))
        table.insert(wrappers, util.wrapMethod(inputbox, "clear", nil, clear_stack))
        -- Navigation
        table.insert(wrappers, util.wrapMethod(inputbox, "upLine", nil, separate))
        table.insert(wrappers, util.wrapMethod(inputbox, "downLine", nil, separate))
        -- Move to other input box
        table.insert(wrappers, util.wrapMethod(inputbox, "unfocus", nil, separate))
        table.insert(wrappers, util.wrapMethod(inputbox, "onCloseKeyboard", nil, separate))
        -- Gestures to move cursor
        table.insert(wrappers, util.wrapMethod(inputbox, "onTapTextBox", nil, separate))
        table.insert(wrappers, util.wrapMethod(inputbox, "onHoldTextBox", nil, separate))
        table.insert(wrappers, util.wrapMethod(inputbox, "onSwipeTextBox", nil, separate))

        table.insert(wrappers, util.wrapMethod(inputbox, "addChars", wrappedAddChars, nil))
        table.insert(wrappers, util.wrapMethod(inputbox, "leftChar", wrappedLeftChar, nil))
        table.insert(wrappers, util.wrapMethod(inputbox, "rightChar", wrappedRightChar, nil))

        return function()
            if inputbox._boshiamy_wrapped then
                for _, wrapper in ipairs(wrappers) do
                    wrapper:revert()
                end
                inputbox._boshiamy_wrapped = nil
            end
        end
    end
end

boshiamy_keyboard.wrapInputBox = wrapInputBox
boshiamy_keyboard.genMenuItems = genMenuItems
boshiamy_keyboard.keys[5][4].label = "空格"
return boshiamy_keyboard
