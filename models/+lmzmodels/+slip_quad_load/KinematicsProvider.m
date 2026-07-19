classdef KinematicsProvider
    methods (Static)
        function value=compute(simulation)
            s=simulation.States;p=simulation.Parameters.quadruped(:);
            legLength=abs(p(11));backRatio=min(0.9,max(0.1,abs(p(13))));
            back=[s(:,1)-backRatio*cos(s(:,5)),s(:,3)-backRatio*sin(s(:,5))];
            front=[s(:,1)+(1-backRatio)*cos(s(:,5)),s(:,3)+(1-backRatio)*sin(s(:,5))];
            angles=s(:,[7 9 11 13])+s(:,5);attachX=[back(:,1),front(:,1),back(:,1),front(:,1)];
            attachY=[back(:,2),front(:,2),back(:,2),front(:,2)];lengths=legLength*ones(size(angles));
            modeNames={'back_left','front_left','back_right','front_right'};
            for index=1:4
                contact=logical(simulation.Modes.(modeNames{index}));denominator=cos(angles(:,index));safe=contact&abs(denominator)>1e-10;
                lengths(safe,index)=attachY(safe,index)./denominator(safe);
            end
            value=struct('CenterOfMass',s(:,[1 3]),'BackAttachment',back, ...
                'FrontAttachment',front,'AttachmentX',attachX,'AttachmentY',attachY, ...
                'FootX',attachX+lengths.*sin(angles),'FootY',attachY-lengths.*cos(angles), ...
                'LoadPosition',s(:,[15 17]),'RopeStart',s(:,[1 3]),'RopeEnd',s(:,[15 17]), ...
                'LegNames',{{'back_left','front_left','back_right','front_right'}});
        end
        function value=frame(simulation,index)
            all=simulation.Kinematics;if isempty(fieldnames(all)),all=lmzmodels.slip_quad_load.KinematicsProvider.compute(simulation);end
            fields={'CenterOfMass','BackAttachment','FrontAttachment','AttachmentX', ...
                'AttachmentY','FootX','FootY','LoadPosition','RopeStart','RopeEnd'};value=struct();
            for fieldIndex=1:numel(fields),value.(fields{fieldIndex})=all.(fields{fieldIndex})(index,:);end
            value.LegNames=all.LegNames;value.Index=index;value.Time=simulation.Time(index);
        end
    end
end
