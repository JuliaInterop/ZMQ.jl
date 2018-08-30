# Utility to make it easier to define get/setproperty for a long list of options.

# build up the body of get/setproperty from a list of properties, of the form
#     if name === $prop
#         ($doit(prop))
#     elseif ...
# for getproperty(value, name) or setproperty!(value, name, x)
function propexpression(doit::Function, properties)
    ex = :(error(typeof(value), " has no field ", name))
    for prop in properties
        ex = Expr(:elseif, :(name === $(QuoteNode(prop))), doit(prop), ex)
    end
    return Expr(:if, ex.args...)
end
