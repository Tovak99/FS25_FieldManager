-- Menüseite "Feldübersicht" für das ESC-Menü.
-- Die Seite selbst ist ein leerer Rahmen; die Kacheln zeichnet FieldListHUD
-- (siehe FieldListHUD:drawInMenu), solange diese Seite aktiv ist.

FieldListHUDFrame = {}
local FieldListHUDFrame_mt = Class(FieldListHUDFrame, TabbedMenuFrameElement)

function FieldListHUDFrame.new()
    local self = TabbedMenuFrameElement.new(nil, FieldListHUDFrame_mt)
    self.hasCustomMenuButtons = false
    return self
end

function FieldListHUDFrame:onFrameOpen()
    FieldListHUDFrame:superClass().onFrameOpen(self)
    if FieldListHUD ~= nil then
        FieldListHUD.stoneBoost = true -- beim Öffnen fehlende/veraltete Messungen sofort nachholen
        FieldListHUD:refreshFields()
        pcall(FieldListHUD.dumpStates, FieldListHUD)
    end
end

function FieldListHUDFrame:onFrameClose()
    FieldListHUDFrame:superClass().onFrameClose(self)
end

-- Mausrad und Klicks auf der Seite an die Kachelliste weiterreichen
function FieldListHUDFrame:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
    eventUsed = FieldListHUDFrame:superClass().mouseEvent(self, posX, posY, isDown, isUp, button, eventUsed)

    if not eventUsed and FieldListHUD ~= nil and FieldListHUD.onMouse ~= nil then
        if FieldListHUD:onMouse(posX, posY, isDown, isUp, button) then
            eventUsed = true
        end
    end

    return eventUsed
end
