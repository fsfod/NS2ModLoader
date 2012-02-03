//
//   Created by:   fsfod
//

InputKeyHelper = {
	ReverseLookup = {},
	LowerCaseKeyList = {},
}

InputKeyHelper.KeyList = {
	"Escape",
	"Num1",
	"Num2",
	"Num3",
	"Num4",
	"Num5",
	"Num6",
	"Num7",
	"Num8",
	"Num9",
	"Num0",
	"Minus",
	"Equals",
	"Back",
	"Tab",
	"Q",
	"W",
	"E",
	"R",
	"T",
	"Y",
	"U",
	"I",
	"O",
	"P",
	"LeftBracket",
	"RightBracket",
	"Return",
	"LeftControl",
	"A",
	"S",
	"D",
	"F",
	"G",
	"H",
	"J",
	"K",
	"L",
	"Semicolon",
	"Apostrophe",
	"Grave",
	"LeftShift",
	"Backslash",
	"Z",
	"X",
	"C",
	"V",
	"B",
	"N",
	"M",
	"Comma",
	"Period",
	"Slash",
	"RightShift",
	"LeftAlt",
	"Space",
	"Capital",
	"F1",
	"F2",
	"F3",
	"F4",
	"F5",
	"F6",
	"F7",
	"F8",
	"F9",
	"F10",
	"NumLock",
	"Scroll",
	"NumPad7",
	"NumPad8",
	"NumPad9",
	"NumPadSubtract",
	"NumPad4",
	"NumPad5",
	"NumPad6",
	"NumPadAdd",
	"NumPad1",
	"NumPad2",
	"NumPad3",
	"NumPad0",
	"Decimal",
	"F11",
	"F12",
	"F13",
	"F14",
	"F15",
	"NumPadEquals",
	"NumPadEnter",
	"NumPadPeriod",
	"NumPadDivide",
	"NumPadMultiply",
	"RightControl",
	"PrintScreen",
	"RightAlt",
	"Pause",
	"Break",
	"Home",
	"Up",
	"PageUp",
	"Left",
	"Right",
	"End",
	"Down",
	"PageDown",
	"Insert",
	"Delete",
	"LeftWindows",
	"RightWindows",
	"AppMenu",
	"Clear",
	"Less",
	"Help",
	"MouseX",
	"MouseY",
	"MouseZ",
	"MouseButton0",
	"MouseButton1",
	"MouseButton2",
	"MouseButton3",
	"MouseButton4",
	"MouseButton5",
	"MouseButton6",
	"MouseButton7",
	"JoystickX",
	"JoystickY",
	"JoystickZ",
	"JoystickRotationX",
	"JoystickRotationY",
	"JoystickRotationZ",
	"JoystickSlider0",
	"JoystickSlider1",
	"JoystickButton0",
	"JoystickButton1",
	"JoystickButton2",
	"JoystickButton3",
	"JoystickButton4",
	"JoystickButton5",
	"JoystickButton6",
	"JoystickButton7",
	"JoystickButton8",
	"JoystickButton9",
	"JoystickButton10",
	"JoystickPovN",
	"JoystickPovS",
	"JoystickPovE",
	"JoystickPovW",
	//really dumb we have to add these since the engine just sends both scroll up and down events as MouseZ
	"MouseWheelUp",
	"MouseWheelDown",
}

function InputKeyHelper:KeyNameExists(keyName)
	--will handle more than InputKey later on
	return InputKey[keyName] ~= nil
end

function InputKeyHelper:BuildLowerNames()
	
	local lowerList = self.LowerCaseKeyList
	
	for i,keyname in ipairs(self.KeyList) do
		lowerList[keyname:lower()] = keyname
	end
end

function InputKeyHelper:FindAndCorrectKeyName(key)
	
	if(not next(self.LowerCaseKeyList)) then
		self:BuildLowerNames()
	end
	
	return (key and self.LowerCaseKeyList[key:lower()]) or false
end

function InputKeyHelper:ConvertToKeyName(inputkeyNumber, down)
	
	if(not self.KeyList[inputkeyNumber]) then
		error("InputKeyHelper:ConvertToKeyName no matching key with the number ".. (inputkeyNumber and tostring(inputkeyNumber)) or "nil")
	end

  if(inputkeyNumber == InputKey.MouseZ) then
    return (down and "MouseWheelUp") or "MouseWheelDown"
  end

	return self.KeyList[inputkeyNumber]
end

local WheelMessages = nil

local NoUpEvent = {
  [InputKey.MouseZ] = true,
  [InputKey.MouseX] = true,
  [InputKey.MouseY] = true,
}

local KeyDown = {}

function InputKeyHelper:PreProcessKeyEvent(key, down)
  PROFILE("KeyDown:SendKeyEvent")

  local IsRepeat = false

  if(not NoUpEvent[key]) then
    IsRepeat = KeyDown[key] and down
    KeyDown[key] = down
  end

/*
  local eventHandled, wheelDirection

  if(key == InputKey.MouseZ and false) then
    if(WheelMessages == nil) then
      WheelMessages = GetWheelMessages() or false
    end

    if(WheelMessages and #WheelMessages ~= 0) then
      wheelDirection = WheelMessages[1]
      table.remove(WheelMessages, 1)
      
      for i,dir in ipairs(WheelMessages) do
        if((dir < 0 and wheelDirection < 0) or (dir > 0 and wheelDirection > 0)) then
          wheelDirection = wheelDirection+dir
        end
      end
    else
      //just eat any extra wheel events this frame that the engine sent
      //even if windows is configured to 1 scroll for 1 wheel click we can still get more than 1 scroll for a single scroll event if the wheel is spinning fast enough
      eventHandled = true
    end
  end
*/  
  return eventHandled, IsRepeat
end

function InputKeyHelper:Update()
  WheelMessages = nil
end

Event.Hook("UpdateClient", function() InputKeyHelper:Update() end)

function InputKeyHelper:IsCtlDown()
  return KeyDown[InputKey.LeftControl] == true or KeyDown[InputKey.RightControl] == true
end

function InputKeyHelper:IsShiftDown()
  return KeyDown[InputKey.LeftShift] == true or KeyDown[InputKey.RightShift] == true
end

InputKeyHelper.ControlPasteChar = 22
InputKeyHelper.ControlCopyChar = 3

//really need access to the raw WM_CHAR message for this to work correctly since we don't get a seperate Contol key event for some input methords
function InputKeyHelper:ShouldIgnoreChar(character)

  if(InputKeyHelper:IsCtlDown()) then
    local utfString = Locale.WideStringToUTF8String(character)
    local char = utfString:byte(1) 
    
    --Ignore the WM_CHAR event that was generated when someone is trying to use the Control-V to paste or Control-C to copy text
    --so we get the VKEY key event instead in SendKEyEvent
    if(#utfString == 1 and (char == self.ControlPasteChar or char == self.ControlCopyChar)) then
      return true
    end
  end
  
  return false
end

MoveEnum = {
	"PrimaryAttack",
	"SecondaryAttack",
	"NextWeapon",
	"PrevWeapon",
	"Reload",
	"Use",
	"Jump",
	"Crouch",
	"MovementModifier",
	"ShowMap",
	"Buy",
	"ToggleFlashlight",
	"Weapon1",
	"Weapon2",
	"Weapon3",
	"Weapon4",
	"Weapon5",
  
	"ScrollBackward",
	"ScrollRight",
	"ScrollLeft",
	"ScrollForward",
	"Exit",
	
	"Drop",
	"Taunt",
	"Scoreboard",
	
	"ToggleSayings1",
	"ToggleSayings2",
	"ToggleVoteMenu",

	"TeamChat",
	"TextChat",
}

InputBitToName = {}

for _,inputname in ipairs(MoveEnum) do
	InputBitToName[Move[inputname]] = inputname
end