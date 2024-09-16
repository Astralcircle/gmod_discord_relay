Discord.commands['status'] = function()
    local form = {
        ["content"] = "# Сервер онлайн",
        ["embeds"] = nil,
        ["attachments"] = {}
    }

    Discord.send(form)
end
