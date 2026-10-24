--[[

    Creates several tiers of additional technologies for every mined product.
    Fluid products use the barrel item named after the fluid.

]]

local factory_inputs = require("script.factory_inputs")

local item_prototype_types = {
    "item",
    "ammo",
    "capsule",
    "gun",
    "item-with-entity-data",
    "item-with-label",
    "item-with-inventory",
    "item-with-tags",
    "module",
    "spidertron-remote",
    "tool",
    "armor",
    "repair-tool",
    "rail-planner",
}

local tiers = {
    {
        unit = {
            count = 100,
            ingredients = {
                { "automation-science-pack", 1 },
            },
            time = 15,
        },
    },
    {
        unit = {
            count = 100,
            ingredients = {
                { "automation-science-pack", 1 },
                { "logistic-science-pack", 1 },
            },
            time = 15,
        },
    },
    {
        unit = {
            count = 150,
            ingredients = {
                { "automation-science-pack", 1 },
                { "logistic-science-pack", 1 },
            },
            time = 15,
        },
    },
    {
        unit = {
            count = 250,
            ingredients = {
                { "automation-science-pack", 1 },
                { "logistic-science-pack", 1 },
                { "chemical-science-pack", 1 },
            },
            time = 15,
        },
    },
    {
        unit = {
            count = 500,
            ingredients = {
                { "automation-science-pack", 1 },
                { "logistic-science-pack", 1 },
                { "chemical-science-pack", 1 },
                { "production-science-pack", 1 },
            },
            time = 15,
        },
    },
    {
        unit = {
            count = 750,
            ingredients = {
                { "automation-science-pack", 1 },
                { "logistic-science-pack", 1 },
                { "chemical-science-pack", 1 },
                { "production-science-pack", 1 },
                { "utility-science-pack", 1 },
            },
            time = 15,
        },
    },
    {
        unit = {
            count = 1000,
            ingredients = {
                { "automation-science-pack", 1 },
                { "logistic-science-pack", 1 },
                { "chemical-science-pack", 1 },
                { "production-science-pack", 1 },
                { "utility-science-pack", 1 },
            },
            time = 15,
        },
    },
}

local function icon_spec(prototype)
    if prototype == nil then
        return nil
    end
    if prototype.icons then
        return { icons = table.deepcopy(prototype.icons) }
    end
    if prototype.icon then
        return { icon = prototype.icon, icon_size = prototype.icon_size or 64 }
    end
end

local function find_item_prototype(name)
    for _, item_type in ipairs(item_prototype_types) do
        local group = data.raw[item_type]
        if group and group[name] then
            return group[name]
        end
    end
end

local function resource_products(resource)
    local minable = resource.minable
    if minable == nil then
        return {}
    end
    if minable.results then
        return minable.results
    end
    if minable.result then
        return {{ type = "item", name = minable.result }}
    end
    return {}
end

local function describe_product(product, resource)
    local input_name = factory_inputs.item_name_for_product(product)
    if input_name == nil then
        return nil
    end

    local source
    local localised_name
    if product.type == "fluid" then
        local fluid = data.raw.fluid[product.name]
        if fluid == nil or fluid.auto_barrel == false then
            return nil
        end
        source = fluid
        localised_name = fluid.localised_name or { "fluid-name." .. product.name }
    else
        local item = find_item_prototype(product.name)
        if item == nil then
            return nil
        end
        source = item
        localised_name = item.localised_name or { "item-name." .. product.name }
    end

    local icon = icon_spec(source) or icon_spec(resource)
    if icon == nil then
        return nil
    end

    return {
        name = input_name,
        localised_name = localised_name,
        icon = icon,
    }
end

local function create_input_technologies(input)
    if data.raw.technology["factory-extra-" .. input.name .. "-1"] then
        return
    end

    local previous_name = nil
    for i, tier in ipairs(tiers) do
        local name = "factory-extra-" .. input.name .. "-" .. i
        local technology = {
            type = "technology",
            name = name,
            order = "f-i-i",
            prerequisites = { previous_name },
            unit = tier.unit,
            localised_name = {
                "technology-name.extra-resource",
                input.localised_name,
                tostring(i),
            },
        }
        if input.icon.icons then
            technology.icons = input.icon.icons
        else
            technology.icon = input.icon.icon
            technology.icon_size = input.icon.icon_size
        end
        data:extend{ technology }
        previous_name = name
    end
end

local seen_inputs = {}
for _, resource in pairs(data.raw.resource) do
    for _, product in pairs(resource_products(resource)) do
        local input = describe_product(product, resource)
        if input and seen_inputs[input.name] == nil then
            seen_inputs[input.name] = true
            create_input_technologies(input)
        end
    end
end
