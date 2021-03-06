local Textarea = require('nibui.Textarea')
local Text = require('nibui.Text')

local cursor_active = 0
local user_input = ""

local text = Textarea:new(8, 8, 400-16, 200)

local listeners = {}

local t = 0

local disabled = false

local history = {}
local history_ptr = 0

local fps = 0

-- Posicao do cursor dentro da entrda
-- atual
local cursor_position = 1

function init()
    -- Copia a paleta padrão
    for i=1,7 do
        copy_palette(0, i)
    end

    -- Cor 0 transparente
    mask_color(0)
end

function draw()
    if not disabled then
        clear(16)

        text:draw()

        draw_cursor()

        rect(8, 240-24, 400-16, 16, 1)
        print(status_line(), 12, 220)

        -- Print FPS
        -- print(tostring(fps), 0, 0)
    end
end

function listeners_line()
    local line = ''

    for pid, name in pairs(listeners) do
        line = line..('\12 '..name)
    end

    if line ~= '' then
        --line = line..' @ terminal.nib(' .. kernel.getenv('pid') .. ') '
    else
        line = '...'
    end

    return line
end

function status_line()
    return listeners_line()
end

function draw_cursor()
    if cursor_active == 0 then
        if math.floor(t*2)%2 == 0 then
            rect(text.cursor_x, text.cursor_y, 4, 8, 15)
        end
    else
        fill_rect(text.cursor_x, text.cursor_y, 4, 8, 15)
    end
end

function update(dt)
    fps = 1/dt

    t += dt

    receive_messages()

    if not disabled and has_listeners() then
        local input = read_keys()

        if #input > 0 then
            input = input:sub(1, 1)

            cursor_active = .5

            if input == "\08" then
                if #user_input > 0 then
                    text:delete(1)
                    user_input = user_input:sub(0, #user_input-1)
                end
            elseif input == "\13" then
                text:newline()

                send_to_listeners(user_input)
                insert(history, user_input)
                history_ptr = 0

                user_input = ""
            elseif input == '\18' then
            else
                text:add(Text:new(input))
                user_input = user_input..input
            end
        end

        if cursor_active > 0 then
            cursor_active -= dt
        else
            cursor_active = 0
        end

        if button_press(LEFT) then
          text:scroll(8)
        end

        if button_press(RIGHT) then
          text:scroll(-8)
        end

        if button_press(UP) and #history > 0 then
            text:delete(#user_input)
            user_input = history[#history-history_ptr]
            text:add(Text:new(user_input))

            if history_ptr < #history-1 then
                history_ptr += 1
            end
        end

        if button_press(DOWN) and #history > 0 then
            if history_ptr > 0 then
                history_ptr -= 1

                text:delete(#user_input)
                user_input = history[#history-history_ptr]
                text:add(Text:new(user_input))
            else
                text:delete(#user_input)
                user_input = ""
                text:add(Text:new(user_input))
            end
        end
    end
end

function has_listeners()
    for _, _ in pairs(listeners) do
        return true
    end

    return false
end

function lineiter(s)
    if s:sub(-1)~="\n" then s=s.."\n" end
    return s:gmatch("(.-)\n")
end

function add_text(str, bg, fg, swap)
    local line = ''

    for i=1,#str  do
        local c = str:sub(i, i)

        if c == '\n' then
            local new = Text:new(line)

            if bg then
                new:set('background_color', bg)
            end

            text:add(new)
            text:newline()
            line = ''
        else
            line = line..c
        end
    end

    if #line > 0 then
        local new = Text:new(line)

        if bg then
            new:set('background_color', bg)
        end

        text:add(new)
    end
end

function send_to_listeners(text)
    for listener, _ in pairs(listeners) do
        send_message(listener, {input=text})
    end
end

function receive_messages()
    local message

    repeat
        message = receive_message()

        if message then
            if message.print and type(message.print) == "string" then
                add_text(message.print, message.background)
            end

            if message.subscribe and type(message.subscribe) == "number" then
                listeners[message.subscribe] = message.name
            end

            if message.unsubscribe and type(message.unsubscribe) == "number" then
                listeners[message.unsubscribe] = nil
            end

            if message.disable then
                disabled = true
            end

            if message.enable then
                disabled = false
            end
        end
    until not message
end

