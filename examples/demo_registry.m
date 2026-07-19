startup; registry=lmz.registry.ModelRegistry.discover(); disp(registry.listModels());
model=registry.createModel('slip.quadruped.planar.v2'); disp(model.getCapabilities());
