-- // CREDITS: https://wiki.multitheftauto.com/wiki/IsVehicleReversing
function isBackwards(vehicle)
	local m = getElementMatrix(vehicle)
	local x, y, z = getElementVelocity(vehicle)
	local d = (x * m[2][1]) + (y * m[2][2]) + (z * m[2][3])
	return d < 0
end