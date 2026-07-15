export type Case = {
	name: string,
	run: () -> (),
}

local Check = {}

function Check.runAll(cases: { Case }): boolean
	local failures = 0
	for _, case in cases do
		local ok, err = pcall(function(): string?
			case.run()
			return nil
		end)
		if ok then
			print(`  PASS  {case.name}`)
		else
			failures += 1
			print(`  FAIL  {case.name}: {tostring(err)}`)
		end
	end
	return failures == 0
end

function Check.equal(actual: any, expected: any, message: string?)
	if actual ~= expected then
		error(`{message or "equal"}: expected {tostring(expected)}, got {tostring(actual)}`)
	end
end

function Check.isTrue(actual: any, message: string?)
	if actual ~= true then
		error(`{message or "isTrue"}: expected true, got {tostring(actual)}`)
	end
end

function Check.isFalse(actual: any, message: string?)
	if actual ~= false then
		error(`{message or "isFalse"}: expected false, got {tostring(actual)}`)
	end
end

return Check
