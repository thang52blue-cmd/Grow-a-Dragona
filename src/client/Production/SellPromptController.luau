-- Wires the Sell ProximityPrompt on the world-visible Market Stall (tagged "MarketStall" by
-- src/server/Services/MarketStallSpawner.luau) to the Sell screen (src/client/Market/
-- SellScreenUI.luau). Per GDD §8, interacting with the stall opens an itemized breakdown of the
-- player's Production Egg inventory with a single "Sell all" action -- the interaction itself no
-- longer fires the transaction directly.
local CollectionService = game:GetService("CollectionService")

local STALL_TAG = "MarketStall"

local SellPromptController = {}

function SellPromptController.Init(openSellScreen: () -> ())
	local function attach(anchor: Instance)
		local prompt = anchor:FindFirstChildWhichIsA("ProximityPrompt")
		if not prompt then
			return
		end
		prompt.Triggered:Connect(function()
			openSellScreen()
		end)
	end

	for _, anchor in CollectionService:GetTagged(STALL_TAG) do
		attach(anchor)
	end
	CollectionService:GetInstanceAddedSignal(STALL_TAG):Connect(attach)
end

return SellPromptController
