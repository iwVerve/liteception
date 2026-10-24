--[[

    Turns a mined resource product into the item name used by the input GUI.
    Fluid products use the auto-generated barrel, which is named after the fluid.

]]

local factory_inputs = {}

local barrel_suffix = "-barrel"

function factory_inputs.item_name_for_product(product)
    if type(product) ~= "table" or type(product.name) ~= "string" or product.name == "" then
        return nil
    end

    if product.type == "fluid" then
        return product.name .. barrel_suffix
    end

    return product.name
end

function factory_inputs.fluid_name_from_input(item_name)
    if type(item_name) ~= "string" or item_name:sub(-#barrel_suffix) ~= barrel_suffix then
        return nil
    end

    local fluid_name = item_name:sub(1, #item_name - #barrel_suffix)
    if fluid_name == "" then
        return nil
    end

    return fluid_name
end

return factory_inputs
