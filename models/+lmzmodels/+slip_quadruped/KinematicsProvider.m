classdef KinematicsProvider
    %KINEMATICSPROVIDER Body attachments and feet from named physical state.
    methods (Static)
        function value = compute(simulation)
            s = simulation.States;
            p = simulation.Parameters;
            back = [s(:,1)-p.l_b*cos(s(:,5)), s(:,3)-p.l_b*sin(s(:,5))];
            front = [s(:,1)+(1-p.l_b)*cos(s(:,5)), s(:,3)+(1-p.l_b)*sin(s(:,5))];
            angles = s(:,[7 9 11 13]) + s(:,5);
            attachX = [back(:,1),front(:,1),back(:,1),front(:,1)];
            attachY = [back(:,2),front(:,2),back(:,2),front(:,2)];
            lengths = p.l_leg*ones(size(angles));
            modeNames = {'back_left','front_left','back_right','front_right'};
            for index = 1:4
                if isfield(simulation.Modes,modeNames{index})
                    contact = logical(simulation.Modes.(modeNames{index}));
                    denominator = cos(angles(:,index));
                    safe = contact & abs(denominator)>1e-10;
                    lengths(safe,index) = attachY(safe,index)./denominator(safe);
                end
            end
            feetX = attachX + lengths.*sin(angles);
            feetY = attachY - lengths.*cos(angles);
            value = struct('CenterOfMass',s(:,[1 3]), ...
                'BackAttachment',back,'FrontAttachment',front, ...
                'AttachmentX',attachX,'AttachmentY',attachY, ...
                'FootX',feetX,'FootY',feetY, ...
                'LegNames',{{'back_left','front_left','back_right','front_right'}});
        end
        function value = frame(simulation,index)
            all = lmzmodels.slip_quadruped.KinematicsProvider.compute(simulation);
            fields = {'CenterOfMass','BackAttachment','FrontAttachment', ...
                'AttachmentX','AttachmentY','FootX','FootY'};
            value = struct();
            for k = 1:numel(fields), value.(fields{k}) = all.(fields{k})(index,:); end
            value.LegNames = all.LegNames;
            value.Index = index; value.Time = simulation.Time(index);
        end
    end
end
