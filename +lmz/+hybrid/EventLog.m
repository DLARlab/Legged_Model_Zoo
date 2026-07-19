classdef EventLog
    methods (Static),function e=record(name,time,index,pre,post,type),e=struct('name',char(name),'time',time,'schedule_index',index,'type',char(type),'pre_state',pre(:).','post_state',post(:).','has_reset',any(pre(:)~=post(:)));end,end
end
