-- scheduler.lua
local Scheduler = {}
Scheduler.__index = Scheduler

function Scheduler.new()
    local self = setmetatable({}, Scheduler)
    self.jobs = {}
    self.running = false
    return self
end

-- Add a job with name, interval (seconds), and function to call
function Scheduler:addJob(name, interval, callback)
    self.jobs[name] = {
        interval = interval,
        callback = callback,
        nextRun = os.clock() + interval
    }
end

-- Remove a job by name
function Scheduler:removeJob(name)
    self.jobs[name] = nil
end

-- Run the scheduler loop
function Scheduler:start()
    self.running = true
    while self.running do
        local now = os.clock()
        for name, job in pairs(self.jobs) do
            if now >= job.nextRun then
                local ok, err = pcall(job.callback)
                if not ok then
                    print(("Job '%s' failed: %s"):format(name, err))
                end
                job.nextRun = now + job.interval
            end
        end
        os.sleep(0.1) -- prevent tight loop
    end
end

function Scheduler:stop()
    self.running = false
end

return Scheduler
