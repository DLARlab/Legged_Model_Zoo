function app = legged_model_zoo
%LEGGED_MODEL_ZOO Launch the standalone Legged Model Zoo application.
startup;
try
    app = lmz.gui.LeggedModelZooApp();
catch exception
    if usejava('desktop')
        uialert(uifigure('Visible','off'), exception.message, ...
            'Legged Model Zoo could not start');
    end
    rethrow(exception);
end
end
