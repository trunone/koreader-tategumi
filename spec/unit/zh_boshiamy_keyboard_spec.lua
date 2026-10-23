describe("zh_boshiamy_keyboard and generic_ime", function()
    local IME
    local boshiamy_keyboard

    setup(function()
        require("commonrequire")
        _G.G_reader_settings = {
            readSetting = function(self, key, default)
                if key == "keyboard_chinese_boshiamy_settings" then
                    return { show_candi = true }
                end
                return default
            end,
            saveSetting = function() end,
        }
        IME = require("ui/data/keyboardlayouts/generic_ime")
        boshiamy_keyboard = dofile("frontend/ui/data/keyboardlayouts/zh_boshiamy_keyboard.lua")
    end)

    it("should set self._stack and provide getImex() in generic_ime", function()
        local ime = IME:new{ code_map = { a = "對" } }
        assert.is_not_nil(ime._stack)
        assert.is_not_nil(ime:getImex())
        assert.is_equal("", ime:getImex().code)
    end)

    it("should have letter keys on layers 1 and 2 as plain strings", function()
        -- Row 2, Key 1 ("Q")
        assert.is_equal("Q", boshiamy_keyboard.keys[2][1][1])
        assert.is_equal("Q", boshiamy_keyboard.keys[2][1][2])
        -- Row 3, Key 1 ("A")
        assert.is_equal("A", boshiamy_keyboard.keys[3][1][1])
        assert.is_equal("A", boshiamy_keyboard.keys[3][1][2])
        -- Row 4, Key 2 ("Z")
        assert.is_equal("Z", boshiamy_keyboard.keys[4][2][1])
        assert.is_equal("Z", boshiamy_keyboard.keys[4][2][2])
    end)

    it("should correctly handle input and display composition roots and candidates", function()
        local text_content = ""
        local inputbox = {
            addChars = {
                raw_method_call = function(self, str)
                    text_content = text_content .. str
                end,
            },
            delChar = {
                raw_method_call = function(self)
                    local util = require("util")
                    local chars = util.splitToChars(text_content)
                    if #chars > 0 then
                        table.remove(chars, #chars)
                        text_content = table.concat(chars)
                    end
                end,
            },
        }

        boshiamy_keyboard.wrapInputBox(inputbox)

        -- Type 'A'
        inputbox:addChars("A")
        assert.is_not_equal("", text_content)
        assert.is_truthy(text_content:find("%(A%)"))

        -- Separate / Space
        inputbox:addChars(" ")
        assert.is_falsy(text_content:find("%(A%)"))
        assert.is_not_equal("", text_content)
    end)
end)
