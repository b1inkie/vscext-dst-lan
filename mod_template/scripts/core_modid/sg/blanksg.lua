AddStategraphState('wilson',State{
    name = "%(modid)s_blanksg",
    onenter = function(inst)
        inst:PerformBufferedAction()
    end,
})

AddStategraphState('wilson_client',State{
    name = '%(modid)s_blanksg',
    onenter = function(inst)
        inst:PerformPreviewBufferedAction()
    end,
})
