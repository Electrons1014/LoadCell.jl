module LoadCell
export HX711, __init__, read, read_avg, get_grams, tare, power_down, power_up
using Pkg
using PyCall
GPIO = pyimport("RPi.GPIO")

#ENV["PYTHON"] = raw"/usr/bin/python3.6"
#Pkg.build("PyCall")

mutable struct HX711
	output::Int64
	pwr_clock::Int64
	
	gain::Int64
	offset::Int64
	scale::Int64
	power::Bool
end

# output, pwr_clock, gain, offset, scale

function __init__(output::Int64, pwr_clock::Int64, gain::Int64 = 128)
	#output: Serial Data Output pin
	#pwr_clock: Power Down and Serial Clock Input pin
	#gain: set gain 128, 64, 32
	@assert (sum(gain .== [32,64,128]) == 1) "gain must be 32,64, or 128"

	offset = 0
    scale = 1
	gain = log2(gain)
	power = true

	GPIO.setmode(GPIO.BCM)
	GPIO.setup(pwr_clock, GPIO.OUT)
	GPIO.setup(output, GPIO.IN)

	self = HX711(output, pwr_clock, gain, offset, scale, power)
	power_up(self)
	return self
end

function read(self::HX711)

	if GPIO.input(self.output) != 0
		error("NO INPUT"); end
		
	count = 0

	for i in 1:24
		GPIO.output(self.pwr_clock, GPIO.HIGH)
		count = count << 1
		GPIO.output(self.pwr_clock, GPIO.LOW)
			
		if GPIO.input(self.output)
			count += 1
		end
	end

	GPIO.output(self.pwr_clock, GPIO.HIGH)
	count = count ^ 0x800000
	GPIO.output(self.pwr_clock, GPIO.LOW)
				
	# set channel and gain factor for next reading
	for i in 1:self.gain
		GPIO.output(self.pwr_clock, GPIO.HIGH)
		GPIO.output(self.pwr_clock, GPIO.LOW)
	end
		
	return count
end

function read_avg(self::HX711, times::Int = 16)
	sum = 0
	for i in times; sum += read(self); end
	return sum / times
end

function get_grams(self::HX711, times::Int = 16)
	#high number of times will have a slower runtime speed
	value = read_avg(self, times) - self.offset
	return  value / self.scale
end

function tare(self::HX711, times::Int = 16)
	self.offset = read_avg(self, times)
end

function power_down(self::HX711)
	self.power = false
	GPIO.output(self.pwr_clock, GPIO.LOW)
	GPIO.output(self.pwr_clock, GPIO.HIGH)
end

function power_up(self::HX711)
	self.power = true
	GPIO.output(self.pwr_clock, GPIO.LOW)
end
end # module