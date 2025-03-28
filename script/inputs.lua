--[[

    Manages resource inputs to the main factory floor.

]]

-- TODO: Sometimes you get extra resources? No clue what triggers it.

local common = require("static.common")

local inputs = {}

local function get_position(is_indoor, name, direction, id, offset)
    local surface_position_data = is_indoor and storage.factory_data.indoor_pos or storage.factory_data.outdoor_pos
    local position = surface_position_data.positions[direction]

    local offsets = surface_position_data.offsets[direction]

    local offset_x, offset_y
    if direction == defines.direction.north or direction == defines.direction.south then
        offset_x = offsets[id]
        offset_y = 0
    else
        offset_x = 0
        offset_y = offsets[id]
    end

    return {
        position[name][1] + offset_x + offset,
        position[name][2] + offset_y + offset,
    }
end

function inputs.set_item_input(direction, id, input)
    local indoor_surface = game.get_surface(storage.factory.surface_name)
    local outdoor_surface = game.get_surface(storage.factory.placed_on_surface_name)

    local belt_tier_name = storage.belt_tier_name
    local entity_direction = direction + 8
    if entity_direction >= 16 then entity_direction = entity_direction - 16 end

    local chest_position = get_position(false, "chest", direction, id, 0)
    local loader_position = get_position(false, "loader", direction, id, 0)
    local outdoor_belt_position = get_position(false, "belt", direction, id, 0)
    local indoor_belt_position = get_position(true, "belt", direction, id, 0)

    local infinity_chest = outdoor_surface.create_entity{
        name = "infinity-chest",
        position = chest_position,
        force = "player",
    }
    local loader = outdoor_surface.create_entity{
        name = "liteception-loader",
        position = loader_position,
        force = "player",
        type = "output",
        direction = entity_direction,
    }
    local outdoor_belt = outdoor_surface.create_entity{
        name = belt_tier_name .. "transport-belt",
        position = outdoor_belt_position,
        direction = entity_direction,
        force = "player",
        raise_built = true,
    }
    local indoor_belt = indoor_surface.create_entity{
        name = belt_tier_name .. "transport-belt",
        position = indoor_belt_position,
        direction = entity_direction,
        force = "player",
        raise_built = true,
    }

    infinity_chest.set_infinity_container_filter(1, {
        name = input,
        count = 50,
        index = 1,
    })

    infinity_chest.force = "enemy"
    loader.force = "enemy"
    outdoor_belt.force = "enemy"
    indoor_belt.force = "enemy"
end

function inputs.get_item_input(direction, id)
    local outdoor_surface = game.get_surface(storage.factory.placed_on_surface_name)

    local chest_position = get_position(false, "chest", direction, id, 0.5)

    local infinity_chest = outdoor_surface.find_entity("infinity-chest", chest_position)

    if infinity_chest ~= nil then
        local filter = infinity_chest.get_infinity_container_filter(1)
        if filter ~= nil then
            return filter.name
        end
        return nil
    end

    return nil
end

function inputs.set_fluid_input(direction, id, input)
    local fluid_input = input:sub(1, input:find("-barrel") - 1)

    local indoor_surface = game.get_surface(storage.factory.surface_name)
    local outdoor_surface = game.get_surface(storage.factory.placed_on_surface_name)

    local entity_direction = direction + 8
    if entity_direction >= 16 then entity_direction = entity_direction - 16 end

    local infinity_pipe_position = get_position(false, "infinity_pipe", direction, id, 0)
    local indoor_pipe_position = get_position(true, "pipe", direction, id, 0)

    local infinity_pipe_name = common.infinity_pipes[direction]

    local infinity_pipe = outdoor_surface.create_entity{
        name = infinity_pipe_name,
        position = infinity_pipe_position,
        force = "player",
    }
    local indoor_pipe = indoor_surface.create_entity{
        name = "pipe",
        position = indoor_pipe_position,
        force = "player",
        raise_built = true,
    }

    infinity_pipe.set_infinity_pipe_filter({
        name = fluid_input,
        percentage = 100,
    })

    -- TODO: Rotate factory pumps correctly, as they start in the useless output mode.

    infinity_pipe.force = "enemy"
    indoor_pipe.force = "enemy"
end

function inputs.change_input_amount(name, amount)
    local input = storage.available_inputs[name]
    if input and input.amount then
        input.amount = input.amount + amount
    else
        storage.available_inputs[name] = {name = name, amount = 0}
    end
end

function inputs.remove_input(direction, id)
    local indoor_surface = game.get_surface(storage.factory.surface_name)
    local outdoor_surface = game.get_surface(storage.factory.placed_on_surface_name)

    local chest_position = get_position(false, "chest", direction, id, 0.5)
    local outdoor_belt_position = get_position(false, "belt", direction, id, 0.5)
    local indoor_belt_position = get_position(true, "belt", direction, id, 0.5)
    local indoor_pipe_position = get_position(true, "pipe", direction, id, 0.5)

    local infinity_pipe_name = common.infinity_pipes[direction]

    local outside = outdoor_surface.find_entities{ chest_position, outdoor_belt_position }
    if outside[1] == nil then
        outside = outdoor_surface.find_entities{ outdoor_belt_position, chest_position }
    end
    local inside = indoor_surface.find_entities{ indoor_pipe_position, indoor_belt_position }

    for _, entity in pairs(outside) do
        if entity.name == infinity_pipe_name then
            local filter = entity.get_infinity_pipe_filter(1)
            if filter ~= nil then
                inputs.change_input_amount(filter.name .. "-barrel", 1)
            end
        elseif entity.name == "infinity-chest" then
            local filter = entity.get_infinity_container_filter(1)
            if filter ~= nil then
                inputs.change_input_amount(filter.name, 1)
            end
        end
        entity.destroy{ raise_destroy = true }
    end

    for _, entity in pairs(inside) do
        entity.destroy{ raise_destroy = true }
    end
end

function inputs.set_input(direction, id, value)
    storage.selected[direction][id] = value

    inputs.remove_input(direction, id)

    if value ~= nil then
        if value:find("barrel") == nil then
            inputs.set_item_input(direction, id, value)
            inputs.change_input_amount(value, -1)
        else
            inputs.set_fluid_input(direction, id, value)
            inputs.change_input_amount(value, -1)
        end
    end
end

function inputs.add_factory_input(prototype)
    local resource_name
    if prototype.resource_category:find("fluid") ~= nil then
        resource_name = prototype.name .. "-barrel"
    else
        resource_name = prototype.name
    end

    -- Don't duplicate resources
    if storage.available_inputs[resource_name] ~= nil then
        return
    end

    storage.available_inputs[resource_name] = { name = resource_name, amount = 1 }
end

local function replace_belts()
    for _, direction in ipairs(common.directions) do
        for _, id in ipairs(storage.factory_data.gui_inputs[direction]) do
            if id ~= 0 then
                local item = inputs.get_item_input(direction, id)
                if item then
                    inputs.remove_input(direction, id)
                    inputs.set_input(direction, id, item)
                end
            end
        end
    end
end

local function on_init()
    storage.players = {}
    storage.used_items = {}
    storage.available_inputs = {
        ["water-barrel"] = { name = "water-barrel", amount = 1 },
        ["wood"] = { name = "wood", amount = 1 },
    }

    -- Find and add all resources to available_inputs.
    local resources = prototypes.get_entity_filtered{{
        filter = "type",
        type = "resource",
    }}
    for _, prototype in pairs(resources) do
        inputs.add_factory_input(prototype)
    end

    -- Find the slowest belt to use as input connection.
    local slowest_belt_name = nil
    local slowest_belt_speed = nil
    for _, prototype in pairs(prototypes.get_entity_filtered{{ filter = "type", type = "transport-belt" }}) do
        if prototype.type == "transport-belt" then
            if slowest_belt_name == nil then
                slowest_belt_name = prototype.name
                slowest_belt_speed = prototype.belt_speed
            else
                if prototype.belt_speed < slowest_belt_speed then
                    slowest_belt_name = prototype.name
                    slowest_belt_speed = prototype.belt_speed
                end
            end
        end
    end

    -- Trim "-transport-belt" off the belt name.
    local trimmed_belt_name = slowest_belt_name:sub(1, -16)
    if trimmed_belt_name ~= "" then
        trimmed_belt_name = trimmed_belt_name .. "-"
    end
    storage.belt_tier_name = trimmed_belt_name

    storage.selected = {}
    for _, v in pairs(defines.direction) do
        storage.selected[v] = {}
    end
end

local function on_research_finished(event)
    if event.research.name == nil then
        return
    end

    if event.research.name:find("liteception%-belt%-") then
        -- Trim "liteception-belt-" and "-transport-belt"
        local belt_tier_name = event.research.name:sub(18, -16)
        if belt_tier_name ~= "" then
            belt_tier_name = belt_tier_name .. "-"
        end

        local current_name = storage.belt_tier_name .. "transport-belt"
        local current_speed = prototypes.entity[current_name].belt_speed

        local new_name = belt_tier_name .. "transport-belt"
        local new_speed = prototypes.entity[new_name].belt_speed

        if new_speed > current_speed then
            storage.belt_tier_name = belt_tier_name
            replace_belts()
        end
    elseif event.research.name:find("factory%-extra%-") ~= nil then
        local resource_name = event.research.name:sub(15, -3)
        inputs.change_input_amount(resource_name, 1)
    end
end

inputs.lib = {
    on_init = on_init,
    events = {
        [defines.events.on_research_finished] = on_research_finished,
    },
}

return inputs
