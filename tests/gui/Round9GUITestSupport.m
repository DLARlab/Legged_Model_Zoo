classdef Round9GUITestSupport
    %ROUND9GUITESTSUPPORT Shared construction helpers for Round 9 GUI tests.
    methods (Static)
        function [app,preferences,cleanup]=makeApp(modelId,problemId)
            if nargin<2,problemId='';end
            controller=lmz.gui.AppController();
            controller.selectModel(modelId);
            if ~isempty(problemId),controller.selectProblem(problemId);end
            preferences=lmz.gui.PreferencesStore( ...
                'Namespace',Round9GUITestSupport.namespace());
            app=lmz.gui.LeggedModelZooApp('Controller',controller, ...
                'Preferences',preferences,'Visible','off');
            cleanup=onCleanup(@()Round9GUITestSupport.clean( ...
                app,preferences));
            drawnow;
        end

        function value=quadPlan()
            catalog=lmzmodels.slip_quad_load.ScientificDatasetCatalog.default();
            dataset=catalog.load('individual_1_tr_to_rl');
            value=lmzmodels.slip_quad_load.XAccumPlanAdapter.toPlan( ...
                dataset.XAccum);
        end

        function [path,cleanup]=savePlan(plan)
            path=[tempname '.mat'];
            lmz.io.ArtifactStore.save(path,plan.toArtifact());
            cleanup=onCleanup(@()Round9GUITestSupport.deleteFile(path));
        end

        function change(control,value)
            control.Value=value;
            callback=control.ValueChangedFcn;
            callback(control,[]);
            drawnow;
        end

        function press(control)
            callback=control.ButtonPushedFcn;
            callback(control,[]);
            drawnow;
        end

        function value=namespace()
            [~,token]=fileparts(tempname);
            value=['LMZRound9GUI' regexprep(token,'[^A-Za-z0-9]','')];
        end

        function clean(app,preferences)
            if ~isempty(app)&&isvalid(app),delete(app);end
            preferences.reset();
        end

        function deleteFile(path)
            if exist(path,'file')==2,delete(path);end
        end
    end
end
