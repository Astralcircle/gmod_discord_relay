net.Receive("!!discord-receive", function()
	local msg = net.ReadTable()

	chat.AddText( Discord.prefixClr, "["..Discord.prefix.."] ", Color(255, 255, 100), msg.author, Color(255, 255, 255), ": ", msg.content )
end)
