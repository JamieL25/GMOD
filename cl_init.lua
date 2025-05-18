-- cl_init.lua (Client-side) - Updated 2025-05-14 22:41:02
-- FIX: Completely reworked zone system to fix player visibility issues
-- FIX: Fixed C key to work properly with CW 2 weapon attachments
-- ADDED: Custom Q-menu for regular players with F4 menu information
-- ADDED: Dynamic prop/tool management system for superadmins

include("shared.lua")

local MainMenu = nil -- Reference to the main VGUI menu
local menuToggleKey = KEY_F2 -- Key to toggle the menu
local menuToggleKeyPressedLast = false -- State tracking for key press

-- CUSTOM Q-MENU STORAGE
local BG_CustomMenu = nil

-- Lists for the custom Q-menu (will be populated from server)
local BG_AllowedProps = {}
local BG_AllowedTools = {}

-- Default tool commands mapping
local BG_DefaultToolCommands = {
    ["Weld Tool"] = "weld",
    ["Rope Tool"] = "rope",
    ["Axis Tool"] = "axis",
    ["Ballsocket Tool"] = "ballsocket"
}

-- Register network strings on client
net.Receive("BG_SyncAllowedProps", function()
    local propCount = net.ReadUInt(16)
    BG_AllowedProps = {}
    
    for i = 1, propCount do
        table.insert(BG_AllowedProps, net.ReadString())
    end
    
    print("[BG Menu] Received " .. propCount .. " allowed props from server")
end)

net.Receive("BG_SyncAllowedTools", function()
    local toolCount = net.ReadUInt(8)
    BG_AllowedTools = {}
    
    for i = 1, toolCount do
        local name = net.ReadString()
        local command = net.ReadString()
        local description = net.ReadString()
        
        table.insert(BG_AllowedTools, {
            name = name,
            command = command,
            description = description
        })
    end
    
    print("[BG Menu] Received " .. toolCount .. " allowed tools from server")
end)

-- Request the prop and tool lists when client initializes
hook.Add("InitPostEntity", "BG_RequestQMenuLists", function()
    timer.Simple(3, function()
        net.Start("BG_RequestQMenuLists")
        net.SendToServer()
    end)
end)

-- DEPLOY MENU FUNCTION (Handles opening and closing the F2 menu)
function OpenMainMenu()
    -- Prevent opening multiple menus
    if IsValid(MainMenu) then return end

    local frameWidth = 400
    local frameHeight = 300

    MainMenu = vgui.Create("DFrame")
    MainMenu:SetSize(frameWidth, frameHeight)
    MainMenu:SetTitle("Welcome to Battlegrounds PVP")
    MainMenu:ShowCloseButton(true); -- Show the 'X' button
    MainMenu:SetDraggable(true); -- Allow dragging the menu
    MainMenu:Center(); -- Center on screen
    MainMenu:MakePopup() -- Make it modal (blocks interaction behind it)

    -- Define OnRemove FIRST to ensure MainMenu is nilled when closed/removed
    MainMenu.OnRemove = function(self)
        print("[Menu Debug] MainMenu OnRemove called.")
        MainMenu = nil -- Ensure reference is cleared so IsValid(MainMenu) works correctly
    end

    -- Define OnClose to handle the 'X' button press specifically
    MainMenu.OnClose = function(self)
        local ply = LocalPlayer()
        if IsValid(ply) and ply:IsFrozen() then
            print("[Menu Debug] Menu closed via 'X' while frozen. Sending ConfirmStaySafe.")
            net.Start("ConfirmStaySafe") -- Tell server the player chose to stay
            net.SendToServer()
        else
             print("[Menu Debug] Menu closed via 'X' while NOT frozen.")
        end
    end

    -- Custom painting for the menu background and title
    MainMenu.Paint = function(self, w, h)
        surface.SetDrawColor(50, 50, 50, 230); -- Dark semi-transparent background
        surface.DrawRect(0, 0, w, h);
        draw.SimpleText("Choose your destination:", "DermaDefaultBold", w/2, 35, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER)
    end

    -- Deploy Button
    local deployBtn = vgui.Create("DButton", MainMenu);
    deployBtn:SetSize(frameWidth - 40, 40);
    deployBtn:SetPos(20, 60);
    deployBtn:SetText("Deploy to Combat Zone");
    deployBtn:SetFont("DermaDefaultBold");
    deployBtn:SetTextColor( Color(255, 255, 255, 255) );
    deployBtn.Paint = function(self, w, h)
        local bgColor = Color(60, 150, 60, 255);
        if not self:IsEnabled() then bgColor = Color(80, 80, 80, 200)
        elseif self:IsHovered() then bgColor = Color(80, 180, 80, 255)
        end;
        draw.RoundedBox(4, 0, 0, w, h, bgColor)
    end
    deployBtn.DoClick = function()
        if not IsValid(MainMenu) or not IsValid(deployBtn) or not deployBtn:IsEnabled() then return end;
        net.Start("DeployPlayer");
        net.SendToServer();
        MainMenu:Remove()
    end

    -- Stay in Safe Zone Button
    local safeBtn = vgui.Create("DButton", MainMenu);
    safeBtn:SetSize(frameWidth - 40, 40);
    safeBtn:SetPos(20, 110);
    safeBtn:SetText("Stay in Safe Zone (Unfreeze)");
    safeBtn:SetFont("DermaDefaultBold");
    safeBtn:SetTextColor( Color(255, 255, 255, 255) );
    safeBtn.Paint = function(self, w, h)
        local bgColor = self:IsHovered() and Color(80, 80, 180, 255) or Color(60, 60, 150, 255);
        draw.RoundedBox(4, 0, 0, w, h, bgColor)
    end
    safeBtn.DoClick = function()
        net.Start("ConfirmStaySafe");
        net.SendToServer();
        if IsValid(MainMenu) then MainMenu:Remove() end
    end

    -- Placeholder Donation Ranks Button
    local donateBtn = vgui.Create("DButton", MainMenu);
    donateBtn:SetSize(frameWidth - 40, 40);
    donateBtn:SetPos(20, 160);
    donateBtn:SetText("Donation Ranks (Placeholder)");
    donateBtn:SetFont("DermaDefaultBold");
    donateBtn:SetTextColor( Color(255, 255, 255, 255) );
    donateBtn.Paint = function(self, w, h)
        local bgColor = self:IsHovered() and Color(100, 100, 100, 255) or Color(80, 80, 80, 255);
        draw.RoundedBox(4, 0, 0, w, h, bgColor)
    end
    donateBtn.DoClick = function()
        print("[Menu] Donation Ranks button clicked (No action configured)")
    end

    -- Client-Side Check to Disable/Enable Buttons based on current state
    local ply = LocalPlayer();
    if IsValid(ply) then
        local canDeploy = ply:GetNWBool("InSafeZone", true);
        deployBtn:SetEnabled(canDeploy)
        safeBtn:SetEnabled(ply:IsFrozen())
    else
        deployBtn:SetEnabled(false);
        safeBtn:SetEnabled(false);
        donateBtn:SetEnabled(false)
    end

    -- Text Labels for Instructions
    local helpText1 = vgui.Create("DLabel", MainMenu);
    helpText1:SetPos(20, 210); helpText1:SetSize(frameWidth - 40, 20);
    helpText1:SetText("Deploy Zone: Fight against other players.");
    helpText1:SetWrap(true); helpText1:SetDark(false)

    local helpText2 = vgui.Create("DLabel", MainMenu);
    helpText2:SetPos(20, 235); helpText2:SetSize(frameWidth - 40, 40);
    helpText2:SetText("Safe Zone: Use '!safe' later if needed (subject to cooldown). Choose 'Stay Safe' to unfreeze now.");
    helpText2:SetWrap(true); helpText2:SetDark(false)
end

-- Q-MENU MANAGEMENT UI (For superadmins)
function OpenQMenuManager()
    if not LocalPlayer():IsSuperAdmin() then
        chat.AddText(Color(255, 100, 100), "Only superadmins can access the Q-Menu Manager!")
        return
    end

    local managerFrame = vgui.Create("DFrame")
    managerFrame:SetTitle("Battlegrounds PVP - Q-Menu Manager")
    managerFrame:SetSize(900, 700)
    managerFrame:Center()
    managerFrame:MakePopup()
    
    local tabs = vgui.Create("DPropertySheet", managerFrame)
    tabs:Dock(FILL)
    tabs:DockMargin(5, 5, 5, 5)
    
    -- Props Manager Tab
    local propsPanel = vgui.Create("DPanel")
    
    local propsLabel = vgui.Create("DLabel", propsPanel)
    propsLabel:SetText("Manage Available Props")
    propsLabel:SetFont("DermaLarge")
    propsLabel:SetPos(10, 10)
    propsLabel:SetSize(500, 30)
    
    -- Props List (Current props)
    local propsList = vgui.Create("DListView", propsPanel)
    propsList:SetPos(10, 50)
    propsList:SetSize(430, 500)
    propsList:SetMultiSelect(false)
    propsList:AddColumn("Prop Model")
    propsList:AddColumn("Preview")
    
    -- Populate the props list
    local function RefreshPropsList()
        propsList:Clear()
        
        for _, model in ipairs(BG_AllowedProps) do
            local line = propsList:AddLine(model, "View")
            line.Model = model
        end
    end
    
    -- Add prop field
    local propModelEntry = vgui.Create("DTextEntry", propsPanel)
    propModelEntry:SetPos(10, 560)
    propModelEntry:SetSize(300, 30)
    propModelEntry:SetPlaceholderText("Enter prop model path")
    
    -- Add prop button
    local addPropBtn = vgui.Create("DButton", propsPanel)
    addPropBtn:SetText("Add Prop")
    addPropBtn:SetPos(320, 560)
    addPropBtn:SetSize(120, 30)
    addPropBtn.DoClick = function()
        local model = propModelEntry:GetValue()
        if model and string.len(model) > 10 then
            net.Start("BG_AdminAddProp")
            net.WriteString(model)
            net.SendToServer()
            propModelEntry:SetValue("")
        end
    end
    
    -- Remove prop button
    local removePropBtn = vgui.Create("DButton", propsPanel)
    removePropBtn:SetText("Remove Selected")
    removePropBtn:SetPos(320, 600)
    removePropBtn:SetSize(120, 30)
    removePropBtn.DoClick = function()
        local selectedLine = propsList:GetSelectedLine()
        if selectedLine then
            local model = propsList:GetLine(selectedLine).Model
            net.Start("BG_AdminRemoveProp")
            net.WriteString(model)
            net.SendToServer()
        end
    end
    
    -- Prop preview
    local propPreview = vgui.Create("DModelPanel", propsPanel)
    propPreview:SetPos(450, 50)
    propPreview:SetSize(430, 430)
    propPreview:SetModel("models/props_c17/FurnitureTable001a.mdl")
    propPreview:SetCamPos(Vector(50, 50, 50))
    propPreview:SetLookAt(Vector(0, 0, 0))
    propPreview:SetFOV(70)
    
    -- Update preview when a prop is selected
    propsList.OnRowSelected = function(lst, index, pnl)
        propPreview:SetModel(pnl.Model)
    end
    
    -- Tools Manager Tab
    local toolsPanel = vgui.Create("DPanel")
    
    local toolsLabel = vgui.Create("DLabel", toolsPanel)
    toolsLabel:SetText("Manage Available Tools")
    toolsLabel:SetFont("DermaLarge")
    toolsLabel:SetPos(10, 10)
    toolsLabel:SetSize(500, 30)
    
    -- Tools List
    local toolsList = vgui.Create("DListView", toolsPanel)
    toolsList:SetPos(10, 50)
    toolsList:SetSize(430, 500)
    toolsList:SetMultiSelect(false)
    toolsList:AddColumn("Tool Name")
    toolsList:AddColumn("Command")
    toolsList:AddColumn("Description")
    
    -- Populate the tools list
    local function RefreshToolsList()
        toolsList:Clear()
        
        for _, tool in ipairs(BG_AllowedTools) do
            local line = toolsList:AddLine(tool.name, tool.command, tool.description)
            line.ToolData = tool
        end
    end
    
    -- Add tool fields
    local toolNameEntry = vgui.Create("DTextEntry", toolsPanel)
    toolNameEntry:SetPos(10, 560)
    toolNameEntry:SetSize(200, 30)
    toolNameEntry:SetPlaceholderText("Tool Name (e.g. Weld Tool)")
    
    local toolCmdEntry = vgui.Create("DTextEntry", toolsPanel)
    toolCmdEntry:SetPos(220, 560)
    toolCmdEntry:SetSize(200, 30)
    toolCmdEntry:SetPlaceholderText("Tool Command (e.g. weld)")
    
    local toolDescEntry = vgui.Create("DTextEntry", toolsPanel)
    toolDescEntry:SetPos(10, 600)
    toolDescEntry:SetSize(410, 30)
    toolDescEntry:SetPlaceholderText("Tool Description")
    
    -- Add tool button
    local addToolBtn = vgui.Create("DButton", toolsPanel)
    addToolBtn:SetText("Add Tool")
    addToolBtn:SetPos(430, 560)
    addToolBtn:SetSize(120, 30)
    addToolBtn.DoClick = function()
        local name = toolNameEntry:GetValue()
        local command = toolCmdEntry:GetValue()
        local description = toolDescEntry:GetValue()
        
        if name and command and string.len(name) > 0 and string.len(command) > 0 then
            if not description or string.len(description) == 0 then
                description = "No description available"
            end
            
            net.Start("BG_AdminAddTool")
            net.WriteString(name)
            net.WriteString(command)
            net.WriteString(description)
            net.SendToServer()
            
            toolNameEntry:SetValue("")
            toolCmdEntry:SetValue("")
            toolDescEntry:SetValue("")
        end
    end
    
    -- Remove tool button
    local removeToolBtn = vgui.Create("DButton", toolsPanel)
    removeToolBtn:SetText("Remove Selected")
    removeToolBtn:SetPos(430, 600)
    removeToolBtn:SetSize(120, 30)
    removeToolBtn.DoClick = function()
        local selectedLine = toolsList:GetSelectedLine()
        if selectedLine then
            local toolName = toolsList:GetLine(selectedLine).ToolData.name
            net.Start("BG_AdminRemoveTool")
            net.WriteString(toolName)
            net.SendToServer()
        end
    end
    
    -- Tool info panel
    local toolInfoPanel = vgui.Create("DPanel", toolsPanel)
    toolInfoPanel:SetPos(560, 50)
    toolInfoPanel:SetSize(320, 500)
    toolInfoPanel.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(50, 50, 50, 100))
        draw.SimpleText("Tool Information", "DermaLarge", w/2, 20, Color(255, 255, 255, 200), TEXT_ALIGN_CENTER)
    end
    
    local toolInfoText = vgui.Create("RichText", toolInfoPanel)
    toolInfoText:SetPos(10, 50)
    toolInfoText:SetSize(300, 440)
    
    -- Update tool info when a tool is selected
    toolsList.OnRowSelected = function(lst, index, pnl)
        local tool = pnl.ToolData
        
        toolInfoText:SetText("")
        toolInfoText:InsertColorChange(220, 220, 220, 255)
        toolInfoText:AppendText("Tool: " .. tool.name .. "\n\n")
        toolInfoText:InsertColorChange(180, 230, 180, 255)
        toolInfoText:AppendText("Command: " .. tool.command .. "\n\n")
        toolInfoText:InsertColorChange(255, 255, 255, 255)
        toolInfoText:AppendText("Description: " .. tool.description .. "\n\n")
        
        toolInfoText:InsertColorChange(200, 200, 255, 255)
        toolInfoText:AppendText("Usage:\n")
        toolInfoText:InsertColorChange(220, 220, 220, 255)
        toolInfoText:AppendText("1. Select the tool from the Q-menu\n")
        toolInfoText:AppendText("2. Left-click on objects to use primary function\n")
        toolInfoText:AppendText("3. Right-click on objects to use secondary function (if available)\n")
        toolInfoText:AppendText("4. Reload key to reset the tool")
    end
    
    -- Refresh both lists whenever they might have changed
    local function RefreshLists()
        RefreshPropsList()
        RefreshToolsList()
    end
    
    -- Add tabs to the manager
    tabs:AddSheet("Props Manager", propsPanel, "icon16/brick.png")
    tabs:AddSheet("Tools Manager", toolsPanel, "icon16/wrench.png")
    
    -- Reset buttons for each tab
    local resetDefaultProps = vgui.Create("DButton", propsPanel)
    resetDefaultProps:SetText("Reset to Default Props")
    resetDefaultProps:SetPos(10, 600)
    resetDefaultProps:SetSize(200, 30)
    resetDefaultProps.DoClick = function()
        Derma_Query(
            "Are you sure you want to reset to default props? This will remove all custom props.",
            "Confirm Reset",
            "Yes", function()
                net.Start("BG_AdminResetProps")
                net.SendToServer()
            end,
            "No", function() end
        )
    end
    
    local resetDefaultTools = vgui.Create("DButton", toolsPanel)
    resetDefaultTools:SetText("Reset to Default Tools")
    resetDefaultTools:SetPos(560, 600)
    resetDefaultTools:SetSize(200, 30)
    resetDefaultTools.DoClick = function()
        Derma_Query(
            "Are you sure you want to reset to default tools? This will remove all custom tools.",
            "Confirm Reset",
            "Yes", function()
                net.Start("BG_AdminResetTools")
                net.SendToServer()
            end,
            "No", function() end
        )
    end
    
    -- Register for sync updates
    hook.Add("BG_ListsUpdated", "RefreshQMenuManagerLists", RefreshLists)
    
    -- Initial population
    RefreshLists()
    
    -- Clean up hook when frame closes
    managerFrame.OnRemove = function()
        hook.Remove("BG_ListsUpdated", "RefreshQMenuManagerLists")
    end
end

-- Create our custom menu function
function ShowBattlegroundsCustomMenu()
    if IsValid(BG_CustomMenu) then
        BG_CustomMenu:Remove()
        return
    end
    
    -- Check for empty lists and request them if needed
    if #BG_AllowedProps == 0 or #BG_AllowedTools == 0 then
        net.Start("BG_RequestQMenuLists")
        net.SendToServer()
    end
    
    BG_CustomMenu = vgui.Create("DFrame")
    BG_CustomMenu:SetTitle("Battlegrounds PVP - Spawn Menu")
    BG_CustomMenu:SetSize(800, 600)
    BG_CustomMenu:Center()
    BG_CustomMenu:MakePopup()
    
    -- Basic theme for the menu
    BG_CustomMenu.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(40, 40, 40, 230))
        surface.SetDrawColor(60, 100, 150, 255)
        surface.DrawOutlinedRect(0, 0, w, h)
    end
    
    -- Create tabs
    local tabs = vgui.Create("DPropertySheet", BG_CustomMenu)
    tabs:Dock(FILL)
    tabs:DockMargin(5, 5, 5, 5)
    
    -- Props Panel
    local propsPanel = vgui.Create("DPanel")
    propsPanel.Paint = function(self, w, h) draw.RoundedBox(0, 0, 0, w, h, Color(50, 50, 50, 100)) end
    
    local propsScroll = vgui.Create("DScrollPanel", propsPanel)
    propsScroll:Dock(FILL)
    propsScroll:DockMargin(10, 10, 10, 10)
    
    local iconLayout = vgui.Create("DIconLayout", propsScroll)
    iconLayout:Dock(FILL)
    iconLayout:SetSpaceX(5)
    iconLayout:SetSpaceY(5)
    
    -- Create title at the top
    local propsTitle = vgui.Create("DLabel", propsPanel)
    propsTitle:SetText("Available Props")
    propsTitle:SetFont("DermaLarge")
    propsTitle:SetTextColor(Color(220, 220, 220))
    propsTitle:Dock(TOP)
    propsTitle:DockMargin(10, 5, 10, 10)
    propsTitle:SetContentAlignment(5) -- Center
    
    -- Add allowed props
    for _, model in pairs(BG_AllowedProps) do
        local icon = iconLayout:Add("SpawnIcon")
        icon:SetModel(model)
        icon:SetSize(64, 64)
        icon.DoClick = function()
            RunConsoleCommand("gm_spawn", model)
            surface.PlaySound("ui/buttonclickrelease.wav")
        end
    end
    
    tabs:AddSheet("Props", propsPanel, "icon16/brick.png")
    
    -- Tools Panel (basic tools only)
    local toolsPanel = vgui.Create("DPanel")
    toolsPanel.Paint = function(self, w, h) draw.RoundedBox(0, 0, 0, w, h, Color(50, 50, 50, 100)) end
    
    local toolsTitle = vgui.Create("DLabel", toolsPanel)
    toolsTitle:SetText("Available Tools")
    toolsTitle:SetFont("DermaLarge")
    toolsTitle:SetTextColor(Color(220, 220, 220))
    toolsTitle:Dock(TOP)
    toolsTitle:DockMargin(10, 5, 10, 10)
    toolsTitle:SetContentAlignment(5) -- Center
    
    -- Simple tools list
    local toolsList = vgui.Create("DListView", toolsPanel)
    toolsList:Dock(FILL)
    toolsList:DockMargin(10, 5, 10, 10)
    toolsList:SetMultiSelect(false)
    toolsList:AddColumn("Tool Name")
    toolsList:AddColumn("Description")
    
    -- Add tools from the allowed list
    for _, tool in ipairs(BG_AllowedTools) do
        toolsList:AddLine(tool.name, tool.description)
    end
    
    toolsList.OnRowSelected = function(lst, index, pnl)
        local toolName = pnl:GetColumnText(1)
        
        -- Find the tool command
        local toolCommand = nil
        for _, tool in ipairs(BG_AllowedTools) do
            if tool.name == toolName then
                toolCommand = tool.command
                break
            end
        end
        
        if toolCommand then
            RunConsoleCommand("gmod_tool", toolCommand)
            surface.PlaySound("ui/buttonclickrelease.wav")
        end
    end
    
    tabs:AddSheet("Tools", toolsPanel, "icon16/wrench.png")
    
    -- Help Panel
    local helpPanel = vgui.Create("DPanel")
    helpPanel.Paint = function(self, w, h) draw.RoundedBox(0, 0, 0, w, h, Color(50, 50, 50, 100)) end
    
    local helpText = vgui.Create("RichText", helpPanel)
    helpText:Dock(FILL)
    helpText:DockMargin(20, 20, 20, 20)
    helpText:SetVerticalScrollbarEnabled(true)
    
    helpText:InsertColorChange(220, 220, 220, 255)
    helpText:AppendText("BATTLEGROUNDS PVP HELP\n\n")
    
    helpText:InsertColorChange(200, 255, 200, 255)
    helpText:AppendText("COMMANDS:\n")
    helpText:InsertColorChange(255, 255, 255, 255)
    helpText:AppendText("!deploy - Move from safe zone to combat zone\n")
    helpText:AppendText("!safe - Return to safe zone (has cooldown)\n\n")
    
    helpText:InsertColorChange(200, 255, 200, 255)
    helpText:AppendText("ZONES:\n")
    helpText:InsertColorChange(255, 255, 255, 255)
    helpText:AppendText("Safe Zone - Cannot use weapons, safe from PVP\n")
    helpText:AppendText("Combat Zone - PVP enabled area\n\n")
    
    helpText:InsertColorChange(200, 255, 200, 255)
    helpText:AppendText("CONTROLS:\n")
    helpText:InsertColorChange(255, 255, 255, 255)
    helpText:AppendText("F2 - Open deployment menu\n")
    helpText:AppendText("F6 - Open weapons shop/loadout menu\n")
    helpText:AppendText("Q - Open this spawn menu\n")
    helpText:AppendText("C - Configure CW 2 weapon attachments\n\n")
    
    helpText:InsertColorChange(200, 255, 200, 255)
    helpText:AppendText("WEAPON SHOP (F6 MENU):\n")
    helpText:InsertColorChange(255, 255, 255, 255)
    helpText:AppendText("The F6 menu contains the Battlegrounds PVP weapon shop where you can:\n")
    helpText:AppendText("- Purchase new weapons for your loadout\n")
    helpText:AppendText("- Equip and customize your loadout\n")
    helpText:AppendText("- Buy ammunition and weapon attachments\n")
    helpText:AppendText("- Access special items and equipment\n\n")
	
	helpText:InsertColorChange(200, 255, 200, 255)
helpText:AppendText("CUSTOM SPAWN MENU (F3):\n")
helpText:InsertColorChange(255, 255, 255, 255)
helpText:AppendText("Press F3 to open the custom spawn menu. This menu allows you to spawn entities like armor dispensers and spawn points.\n")
helpText:AppendText("  - Press F3 again to toggle cursor control within the menu.\n")
helpText:AppendText("\n\n")  -- Add two newlines for spacing
helpText:AppendText("Note: Weapons purchased in the F6 menu will be available when you deploy to combat or respawn.\n")
    
    tabs:AddSheet("Help", helpPanel, "icon16/help.png")
    
    -- Add Q-Menu Manager button (only visible to superadmins)
    if LocalPlayer():IsSuperAdmin() then
        local manageBtn = vgui.Create("DButton", BG_CustomMenu)
        manageBtn:SetText("Manage Q-Menu")
        manageBtn:SetSize(150, 30)
        manageBtn:SetPos(10, BG_CustomMenu:GetTall() - 40)
        manageBtn.DoClick = function()
            OpenQMenuManager()
        end
    end
    
    -- Add close button (bottom)
    local closeButton = vgui.Create("DButton", BG_CustomMenu)
    closeButton:SetText("Close Menu")
    closeButton:SetSize(150, 30)
    closeButton:SetPos(BG_CustomMenu:GetWide() - 160, BG_CustomMenu:GetTall() - 40)
    closeButton.DoClick = function()
        BG_CustomMenu:Remove()
    end
end

-- OPEN DEPLOY MENU ON SPAWN (If player is frozen)
function GM:InitPostEntity()
    if self.BaseClass and self.BaseClass.InitPostEntity then self.BaseClass.InitPostEntity(self) end;
    print("[Menu Debug] GM:InitPostEntity Running...");
    local ply = LocalPlayer();
    if not IsValid(ply) then print("[Menu Debug] Player invalid."); return end;
    
    if ply:IsFrozen() and not IsValid(MainMenu) then
        print("[Menu Debug] Player IS frozen, opening menu directly NOW...");
        OpenMainMenu();
        if IsValid(MainMenu) then print("[Menu Debug] Menu IS valid after call.") else print("[Menu Debug] ERROR: Menu is NOT valid after call!") end
    else
        print("[Menu Debug] Condition failed for direct open. Frozen=", ply:IsFrozen(), "MenuValid=", IsValid(MainMenu))
    end
end

-- Think Hook for Menu Toggle (Using F2 Key)
hook.Add("Think", "BattlegroundsPvP_Think_MenuToggle", function()
    local ply = LocalPlayer();
    if not IsValid(ply) then return end;

    local isKeyDown = input.IsKeyDown( menuToggleKey );

    if isKeyDown and not menuToggleKeyPressedLast then
        print("[Menu Debug] F2 Key Down Edge Detected! (Key Code: " .. menuToggleKey .. ")");
        if IsValid(MainMenu) then
            print("[Menu Debug] KeyDown: Menu is valid, removing.");
            MainMenu:Remove()
        else
            -- Allow opening F2 menu even if frozen (unlike Q menu)
            -- if not ply:IsFrozen() then
                print("[Menu Debug] KeyDown: Menu not valid, opening F2 menu.");
                OpenMainMenu()
            -- else
            --    print("[Menu Debug] KeyDown: Menu not valid, but player IS frozen. Not opening via key.")
            -- end
        end
    end;
    menuToggleKeyPressedLast = isKeyDown
end)

-- Q-Menu Permission Hook: PlayerBindPress
-- This hook intercepts key presses. We check if it's the spawn menu key ('+menu')
-- and perform permission checks here. 
function GM:PlayerBindPress(ply, bind, pressed)
    -- Only act when the key is pressed down, not released
    if not pressed then return false end
    
    -- IMPORTANT: Disable GMod's built-in third-person view to avoid conflicts with CW 2
    if bind == "+attack3" or bind == "+attack2" then
        -- Let CW 2 handle this key
        return false
    end
    
    -- Only check the bind for the spawn menu
    if string.lower(bind) ~= "+menu" then return false end

    print("[SpawnMenu Check - BindPress] Player " .. ply:Nick() .. " pressed key for bind: " .. bind)

    -- Block if frozen (This check is important here too!)
    if ply:IsFrozen() then
        print("[SpawnMenu Check - BindPress] Denied: Player is Frozen")
        -- Optional feedback: ply:ChatPrint("Cannot open Spawn Menu while frozen.")
        return true -- Block the bind
    end

    -- *** Check for admin permissions ***
    local hasPermission = false
    local reason = "None"

    -- 1. Check Listen Server Host
    if ply:IsListenServerHost() then
        hasPermission = true; reason = "Listen Server Host"
    -- 2. Check Default GMod IsAdmin()
    elseif ply:IsAdmin() then
        hasPermission = true; reason = "IsAdmin() returned true"
    -- 3. Check CAMI (for SAM etc.)
    elseif CAMI and CAMI.PlayerHasAccess then
        print("[SpawnMenu Check - BindPress] CAMI library found. Checking permissions...")
        if CAMI.PlayerHasAccess(ply, "superadmin", nil) then -- Check specific superadmin group
            hasPermission = true; reason = "CAMI HasAccess 'superadmin'"
            print("[SpawnMenu Check - BindPress] CAMI Granted via 'superadmin'")
        elseif CAMI.PlayerHasAccess(ply, "Tool_Toolgun", nil) then -- Check toolgun access
             hasPermission = true; reason = "CAMI HasAccess 'Tool_Toolgun'"
             print("[SpawnMenu Check - BindPress] CAMI Granted via 'Tool_Toolgun'")
        elseif CAMI.PlayerHasAccess(ply, "Admin", nil) then -- Check general admin access
             hasPermission = true; reason = "CAMI HasAccess 'Admin'"
             print("[SpawnMenu Check - BindPress] CAMI Granted via 'Admin'")
        else
             print("[SpawnMenu Check - BindPress] CAMI HasAccess checks failed for: 'superadmin', 'Tool_Toolgun', 'Admin'")
        end
    else
        print("[SpawnMenu Check - BindPress] CAMI library not found or PlayerHasAccess function missing.")
    end

    -- Final Decision
    if hasPermission then
        print("[SpawnMenu Check - BindPress] RESULT: Allowing standard Q Menu for " .. ply:Nick() .. ". Reason: " .. reason)
        return false -- **** ALLOW standard Q-menu for admins ****
    else
        print("[SpawnMenu Check - BindPress] RESULT: Showing CUSTOM Q Menu for " .. ply:Nick())
        ShowBattlegroundsCustomMenu() -- Show our custom menu instead
        return true -- **** BLOCK the standard Q-menu ****
    end
end

--=============================================================================
-- COMPLETELY REDESIGNED ZONE SYSTEM
--=============================================================================

-- Zone Definitions
local SAFE_ZONE_MIN = Vector(1870.538818, -275.760559, -12532.864258)
local SAFE_ZONE_MAX = Vector(2298.709229,  543.457153, -12235.714844)

-- These are entity classes that should always be visible regardless of zone
local alwaysVisibleEntities = {
    ["player"] = true,            -- ALL PLAYERS ARE ALWAYS VISIBLE
    ["viewmodel"] = true,         -- Player's viewmodel (hands/weapon view)
    ["predicted_viewmodel"] = true, -- Predicted version of viewmodel
    ["gmod_hands"] = true,        -- Player hands
    ["weapon_physgun"] = true,    -- Admin tools
    ["gmod_tool"] = true,         -- Toolgun
    ["weaponbox"] = true          -- Dropped weapons
}

-- Entity storage for zone-based visibility
local safeZoneEntities = {}

-- Function to determine if an entity is in the safe zone
function IsInSafeZone(ent)
    if not IsValid(ent) then return false end
    return ent:GetPos():WithinAABox(SAFE_ZONE_MIN, SAFE_ZONE_MAX)
end

-- Function to check if an entity belongs to the local player
function IsLocalPlayerEntity(ent)
    if not IsValid(ent) then return false end
    
    local ply = LocalPlayer()
    if not IsValid(ply) then return false end
    
    -- Check if it's a weapon held by the local player
    if ent:IsWeapon() and ent:GetOwner() == ply then
        return true
    end
    
    -- Check if it's the player itself
    if ent == ply then
        return true
    end
    
    -- Check viewmodels
    if ent:GetClass() == "viewmodel" or ent:GetClass() == "predicted_viewmodel" then
        return true
    end
    
    return false
end

-- Track entities in safe zone when they're created
hook.Add("OnEntityCreated", "TrackSafeZoneEntities", function(ent)
    timer.Simple(0, function()
        if not IsValid(ent) then return end
        
        -- Never track players or always visible entities
        if ent:IsPlayer() or alwaysVisibleEntities[ent:GetClass()] then
            return
        end
        
        -- Never track the local player's own entities
        if IsLocalPlayerEntity(ent) then
            return
        end
        
        -- If entity is in the safe zone, track it
        if IsInSafeZone(ent) then
            safeZoneEntities[ent] = true
        end
    end)
end)

-- Initial entity tracking on startup
timer.Simple(1, function()
    for _, ent in ipairs(ents.GetAll()) do
        if not IsValid(ent) then continue end
        
        -- Never track players or always visible entities
        if ent:IsPlayer() or alwaysVisibleEntities[ent:GetClass()] then
            continue
        end
        
        -- Never track the local player's own entities
        if IsLocalPlayerEntity(ent) then
            continue
        end
        
        -- If entity is in the safe zone, track it
        if IsInSafeZone(ent) then
            safeZoneEntities[ent] = true
        end
    end
end)

-- Manage visibility of safe zone entities
hook.Add("PreDrawOpaqueRenderables", "ManageSafeZoneEntityVisibility", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local playerInSafeZone = ply:GetNWBool("InSafeZone", false)

    for ent, _ in pairs(safeZoneEntities) do
        if not IsValid(ent) then
            safeZoneEntities[ent] = nil
            continue
        end
        
        -- Skip processing for players and always-visible entities
        if ent:IsPlayer() or alwaysVisibleEntities[ent:GetClass()] then
            ent:SetNoDraw(false)
            continue
        end
        
        -- Never hide the local player's own entities
        if IsLocalPlayerEntity(ent) then
            ent:SetNoDraw(false)
            continue
        end
        
        -- Handle regular safe zone entities based on player location
        if ply:IsFrozen() and playerInSafeZone then
            ent:SetNoDraw(false) -- Show everything to frozen players in safe zone
        else
            -- Only show safe zone entities to players in the safe zone
            ent:SetNoDraw(not playerInSafeZone)
        end
    end
end)

-- THIS IS THE CRUCIAL PART: We never interfere with player drawing
-- Remove all previous hooks that might hide the player
hook.Remove("PrePlayerDraw", "HideSafeZonePlayers_DEBUG")
hook.Remove("PrePlayerDraw", "HideSafeZonePlayers")
hook.Remove("PrePlayerDraw", "BattlegroundsPVP_PlayerDrawing")

-- New simpler system that never hides your own player model
hook.Add("PrePlayerDraw", "SimpleZonePlayerVisibility", function(targetPlayer)
    local viewer = LocalPlayer()
    if not IsValid(viewer) or not IsValid(targetPlayer) then return end
    
    -- NEVER hide the local player to themselves
    if targetPlayer == viewer then
        targetPlayer:SetNoDraw(false)
        targetPlayer:DrawShadow(true)
        targetPlayer:SetRenderMode(RENDERMODE_NORMAL)
        targetPlayer:SetColor(Color(255, 255, 255, 255))
        return false -- Always allow drawing yourself
    end
    
    -- Handle other players: Only hide safe zone players from combat zone players
    local viewerInSafeZone = viewer:GetNWBool("InSafeZone", true)
    local targetInSafeZone = targetPlayer:GetNWBool("InSafeZone", false)
    
    if not viewerInSafeZone and targetInSafeZone then
        -- Combat zone player can't see safe zone players
        targetPlayer:SetRenderMode(RENDERMODE_TRANSALPHA)
        targetPlayer:SetColor(Color(255, 255, 255, 0))
        return true -- Block drawing
    else
        -- In all other cases, players are visible
        targetPlayer:SetRenderMode(RENDERMODE_NORMAL)
        targetPlayer:SetColor(Color(255, 255, 255, 255))
        return false -- Allow drawing
    end
end)

-- Always show hands and viewmodels
hook.Add("PreDrawPlayerHands", "EnsureHandsVisible", function(hands, vm, ply, weapon)
    if IsValid(hands) then hands:SetNoDraw(false) end
    if IsValid(vm) then vm:SetNoDraw(false) end
    return false -- Allow normal rendering
end)

-- CRITICAL: Disable GMod's built-in third-person camera to fix CW 2 compatibility
hook.Remove("CalcView", "ThirdPersonCamera") -- Remove any third-person camera hooks

-- Block GMod's built-in third person switches
concommand.Add("simple_thirdperson_enable_toggle", function() end) -- Block third-person toggle commands
concommand.Add("thirdperson_toggle", function() end) -- Block third-person toggle commands
concommand.Add("thirdperson", function() end) -- Block third-person commands

-- Ensure our player is always visible in third-person modes for any addon compatibility
hook.Add("ShouldDrawLocalPlayer", "StandardThirdPersonSupport", function()
    -- Simply ensure our player model is visible but don't force third-person
    local ply = LocalPlayer()
    if IsValid(ply) then
        ply:SetNoDraw(false)
        ply:DrawShadow(true)
    end
    return nil -- Let other hooks handle whether to draw or not
end)

-- HUD ELEMENTS
local SafeCountdownEnd = 0
local SafeCooldownEnd = 0
local DeployConfirmationEnd = 0

net.Receive("SafeTeleportCountdown", function() 
    SafeCountdownEnd = CurTime() + 4
    SafeCooldownEnd = CurTime() + 120
end)

net.Receive("ConfirmDeploy", function() 
    DeployConfirmationEnd = CurTime() + 3
end)

surface.CreateFont("ZoneHUD_Font", {font = "Trebuchet MS", size = 24, weight = 700, antialias = true})

hook.Add("HUDPaint", "DrawCustomHUD", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local scrW, scrH = ScrW(), ScrH()
    local cx = scrW / 2

    -- Zone Indicator (Top Left)
    local inSafeZone = ply:GetNWBool("InSafeZone", true)
    local zoneText = "Zone: Unknown"
    local zoneColor = Color(200, 200, 200, 200)
    local zoneFont = "ZoneHUD_Font"
    local xPos = 15
    local yPos = 15
    local padding = 5
    local bgColor = Color(0, 0, 0, 170)

    if inSafeZone then
        zoneText = "Zone: Safe"
        zoneColor = Color(100, 255, 100, 255)
    else
        zoneText = "Zone: Combat"
        zoneColor = Color(255, 100, 100, 255)
    end

    surface.SetFont(zoneFont)
    local tw, th = surface.GetTextSize(zoneText)
    local boxX = xPos - padding
    local boxY = yPos - padding
    local boxW = tw + padding * 2
    local boxH = th + padding * 2
    surface.SetDrawColor(bgColor)
    surface.DrawRect(boxX, boxY, boxW, boxH)
    draw.SimpleText(zoneText, zoneFont, xPos, yPos, zoneColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    -- Teleport Countdown Message
    if SafeCountdownEnd > CurTime() then
        draw.SimpleText("Teleporting..." .. math.ceil(SafeCountdownEnd - CurTime()), "DermaLarge", cx, scrH/2 - 100, Color(0,255,0,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- Safe Command Cooldown Message
    if SafeCooldownEnd > CurTime() and SafeCooldownEnd <= CurTime() then
        draw.SimpleText("!safe cooldown: " .. math.ceil(SafeCooldownEnd - CurTime()) .. "s", "DermaDefault", scrW-20, scrH-100, Color(255,255,0,200), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    -- Deploy Confirmation Message
    if DeployConfirmationEnd > CurTime() then
        draw.SimpleText("You have entered the battlefield!", "DermaLarge", cx, scrH/2 - 20, Color(0,200,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- Frozen Message
    if ply:IsFrozen() then
        draw.SimpleText("Choose an option from the F2 Menu", "ZoneHUD_Font", cx, scrH - 160, Color(255, 100, 100, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- F2 Menu Hint
    if not ply:IsFrozen() and not IsValid(MainMenu) then
        local hintText = "Press F2 to toggle menu"
        local hintColor = Color(200, 200, 200, 180)
        local hintFont = "ZoneHUD_Font"
        local hintX = scrW / 2
        local hintY = scrH - 60
        draw.SimpleText(hintText, hintFont, hintX, hintY, hintColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
    end
    
    -- F4 Menu Hint
    if not ply:IsFrozen() then
        local f4Text = "Press F6 for Weapon Shop"
        local f4Color = Color(180, 200, 255, 180)
        local f4Font = "ZoneHUD_Font"
        local f4X = scrW / 2
        local f4Y = scrH - 90 
        draw.SimpleText(f4Text, f4Font, f4X, f4Y, f4Color, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
    end
    
    -- Admin Q-Menu Manager Hint (Superadmins only)
    if ply:IsSuperAdmin() and not ply:IsFrozen() then
        local adminText = "Press Q for custom menu or type !qadmin"
        local adminColor = Color(255, 200, 200, 180)
        local adminFont = "ZoneHUD_Font"
        local adminX = scrW / 2
        local adminY = scrH - 120
        draw.SimpleText(adminText, adminFont, adminX, adminY, adminColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
    end
end)

-- Console command for Q-Menu management
concommand.Add("bg_qmenu_manager", function()
    if LocalPlayer():IsSuperAdmin() then
        OpenQMenuManager()
    else
        chat.AddText(Color(255, 100, 100), "Only superadmins can access the Q-Menu Manager!")
    end
end)

-- SHUTDOWN HOOK
hook.Add("Shutdown", "ResetAllPlayerVisibility", function()
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) then
            ply:SetNoDraw(false)
            ply:DrawShadow(true)
            ply:SetRenderMode(RENDERMODE_NORMAL)
            ply:SetColor(Color(255, 255, 255, 255))
        end
    end
end)

-- Reset ALL entity visibility - useful for debugging
function ResetAllVisibility()
    for _, ent in ipairs(ents.GetAll()) do
        if IsValid(ent) then
            ent:SetNoDraw(false)
            if ent:IsPlayer() then
                ent:DrawShadow(true)
                ent:SetRenderMode(RENDERMODE_NORMAL)
                ent:SetColor(Color(255, 255, 255, 255))
            end
        end
    end
    print("[Debug] Reset visibility for all entities")
end
concommand.Add("bg_reset_visibility", ResetAllVisibility)

-- CRITICAL: Disable GMod's built-in third-person view
-- This is run at file load to ensure it takes effect
do
    -- Disable any built-in GMod third-person functionality
    hook.Remove("CalcView", "ThirdPersonView")
    hook.Remove("ShouldDrawLocalPlayer", "ThirdPersonDrawPlayer")
    
    -- Also try to remove common third-person addons' hooks
    hook.Remove("CalcView", "ThirdPerson_Disabled")
    hook.Remove("CalcView", "ThirdPerson_Enabled") 
    hook.Remove("CalcView", "ThirdPersonCamera")
    
    print("Disabled built-in third-person camera to ensure CW 2 compatibility")
end

-- Test Menu
concommand.Add("bg_test_regular_qmenu", function(ply)
    if IsValid(ply) and ply:IsSuperAdmin() then
        ShowBattlegroundsCustomMenu()
        print("[ADMIN] Viewing regular player Q-menu for testing")
    end
end)

print("Military Gamemode - cl_init.lua loaded (Client - v1.75 - Added dynamic Q-menu management for superadmins)")