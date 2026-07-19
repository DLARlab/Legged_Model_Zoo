classdef KinematicsProvider
    %KINEMATICSPROVIDER Point mass and feet from named biped states.
    methods (Static)
        function value=compute(simulation)
            s=simulation.States;angles=s(:,[5 7]);
            attachX=repmat(s(:,1),1,2);attachY=repmat(s(:,3),1,2);
            lengths=ones(size(angles));contacts=[simulation.Modes.left,simulation.Modes.right];
            for leg=1:2
                denominator=cos(angles(:,leg));safe=contacts(:,leg)&abs(denominator)>1e-10;
                lengths(safe,leg)=s(safe,3)./denominator(safe);
            end
            feetX=attachX+lengths.*sin(angles);feetY=attachY-lengths.*cos(angles);
            feetY(contacts)=0;
            value=struct('CenterOfMass',s(:,[1 3]),'AttachmentX',attachX, ...
                'AttachmentY',attachY,'FootX',feetX,'FootY',feetY, ...
                'LegLength',lengths,'LegNames',{{'left','right'}});
        end
        function value=frame(simulation,index)
            all=simulation.Kinematics;
            if isempty(fieldnames(all)),all=lmzmodels.slip_biped.KinematicsProvider.compute(simulation);end
            fields={'CenterOfMass','AttachmentX','AttachmentY','FootX','FootY','LegLength'};
            value=struct();
            for fieldIndex=1:numel(fields)
                value.(fields{fieldIndex})=all.(fields{fieldIndex})(index,:);
            end
            value.LegNames=all.LegNames;value.Index=index;value.Time=simulation.Time(index);
        end
    end
end
