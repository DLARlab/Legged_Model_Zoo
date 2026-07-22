classdef Round11GUITestSupport
    %ROUND11GUITESTSUPPORT Shared deterministic layout-test helpers.
    methods (Static)
        function [app,preferences,cleanup]=makeApp(profile,sizeValue)
            if nargin<1,profile='scientific_workbench';end
            if nargin<2,sizeValue=[1120 740];end
            preferences=lmz.gui.PreferencesStore( ...
                'Namespace',Round11GUITestSupport.namespace());
            preferences.setLayoutProfile(profile);
            preferences.setWindowPosition([40 40 sizeValue]);
            app=lmz.gui.LeggedModelZooApp('Preferences',preferences, ...
                'Visible','off');
            cleanup=onCleanup(@()Round11GUITestSupport.clean( ...
                app,preferences));
            drawnow;
        end

        function value=scientificLayout(app)
            value=app.WorkbenchShell.Layout;
            if ~isa(value,'lmz.gui.layout.ScientificWorkbenchLayout')
                error('lmz:Test:Layout','Expected scientific workbench.');
            end
        end

        function ids=sidebarIds(layout)
            ids=fieldnames(layout.SidebarHost.Tabs);
        end

        function offenders=enabledControlClipping(viewport)
            content=viewport.Content.Root;
            contentBounds=getpixelposition(content,true);
            handles=findall(content);offenders={};
            for index=1:numel(handles)
                handle=handles(index);
                if isequal(handle,content)||~isprop(handle,'Position')|| ...
                        ~Round11GUITestSupport.effectivelyVisible(handle)|| ...
                        hasAxesAncestor(handle,content)|| ...
                        (isprop(handle,'Enable')&&strcmp(char(handle.Enable),'off'))
                    continue
                end
                if isa(handle.Parent,'matlab.ui.container.GridLayout')
                    if ~layoutFitsGrid(handle,handle.Parent)
                        offenders{end+1}=controlName(handle); %#ok<AGROW>
                    end
                    % MATLAB does not expose the resolved pixel Position of
                    % GridLayout-managed controls reliably in batch mode.
                    % Their parent grid is checked geometrically, while cell
                    % spans are checked structurally here.
                    continue
                end
                try
                    bounds=getpixelposition(handle,true);
                catch
                    continue
                end
                if any(~isfinite(bounds))||any(bounds(3:4)<=0),continue,end
                tolerance=2;
                outside=bounds(1)<contentBounds(1)-tolerance|| ...
                    bounds(2)<contentBounds(2)-tolerance|| ...
                    sum(bounds([1 3]))>sum(contentBounds([1 3]))+tolerance|| ...
                    sum(bounds([2 4]))>sum(contentBounds([2 4]))+tolerance;
                if outside
                    offenders{end+1}=controlName(handle); %#ok<AGROW>
                end
            end
        end

        function offenders=enabledControlClippingAllTabs(viewport)
            offenders=clippingAcrossTabPages(viewport, ...
                viewport.Content.Root);
            offenders=unique(offenders,'stable');
        end

        function offenders=enabledLabelControlOverlap(viewport)
            handles=findall(viewport.Content.Root);labels={};controls={};
            for index=1:numel(handles)
                handle=handles(index);
                if ~isUIControl(handle)||isgraphics(handle,'axes')|| ...
                        ~Round11GUITestSupport.effectivelyVisible(handle)|| ...
                        (isprop(handle,'Enable')&&strcmp(char(handle.Enable),'off'))
                    continue
                end
                if isa(handle,'matlab.ui.control.Label')
                    labels{end+1}=handle; %#ok<AGROW>
                else
                    controls{end+1}=handle; %#ok<AGROW>
                end
            end
            offenders={};
            for labelIndex=1:numel(labels)
                label=labels{labelIndex};
                for controlIndex=1:numel(controls)
                    control=controls{controlIndex};
                    if ~isequal(label.Parent,control.Parent),continue,end
                    if isa(label.Parent,'matlab.ui.container.GridLayout')
                        if layoutCellsOverlap(label,control)
                            offenders{end+1}=overlapName( ...
                                label,control); %#ok<AGROW>
                        end
                        continue
                    end
                    try
                        labelBounds=getpixelposition(label,true);
                        controlBounds=getpixelposition(control,true);
                    catch
                        continue
                    end
                    if rectanglesOverlap(labelBounds,controlBounds,1)
                        offenders{end+1}=overlapName(label,control); %#ok<AGROW>
                    end
                end
            end
            offenders=unique(offenders,'stable');
        end

        function offenders=enabledLabelControlOverlapAllTabs(viewport)
            offenders=overlapAcrossTabPages(viewport, ...
                viewport.Content.Root);
            offenders=unique(offenders,'stable');
        end

        function value=effectivelyVisible(handle)
            value=true;current=handle;
            while ~isempty(current)&&isvalid(current)
                % A hidden UIFigure still has deterministic local layout.
                % Stop here so automated bounds tests honor tab/panel state
                % without rejecting every descendant solely due to headless
                % construction.
                if isa(current,'matlab.ui.Figure'),return,end
                if isprop(current,'Visible')&&strcmp(char(current.Visible),'off')
                    value=false;return
                end
                if isa(current,'matlab.ui.container.Tab')
                    group=current.Parent;
                    if isprop(group,'SelectedTab')&&~isequal(group.SelectedTab,current)
                        value=false;return
                    end
                end
                if ~isprop(current,'Parent'),break,end
                current=current.Parent;
            end
        end

        function value=namespace()
            [~,token]=fileparts(tempname);
            value=['LMZRound11GUI' regexprep(token,'[^A-Za-z0-9]','')];
        end

        function clean(app,preferences)
            if ~isempty(app)&&isvalid(app),delete(app);end
            preferences.reset();
        end
    end
end

function offenders=clippingAcrossTabPages(viewport,container)
settleViewport(viewport);
offenders=Round11GUITestSupport.enabledControlClipping(viewport);
groups=topLevelTabGroups(container);
for groupIndex=1:numel(groups)
    group=groups{groupIndex};
    if isempty(group)||~isvalid(group)||isempty(group.Children),continue,end
    original=group.SelectedTab;
    restore=onCleanup(@()restoreSelectedTab(group,original));
    tabs=group.Children;
    for tabIndex=1:numel(tabs)
        group.SelectedTab=tabs(tabIndex);settleViewport(viewport);
        offenders=[offenders clippingAcrossTabPages( ...
            viewport,tabs(tabIndex))]; %#ok<AGROW>
    end
    clear restore
end
end

function offenders=overlapAcrossTabPages(viewport,container)
settleViewport(viewport);
offenders=Round11GUITestSupport.enabledLabelControlOverlap(viewport);
groups=topLevelTabGroups(container);
for groupIndex=1:numel(groups)
    group=groups{groupIndex};
    if isempty(group)||~isvalid(group)||isempty(group.Children),continue,end
    original=group.SelectedTab;
    restore=onCleanup(@()restoreSelectedTab(group,original));
    tabs=group.Children;
    for tabIndex=1:numel(tabs)
        group.SelectedTab=tabs(tabIndex);settleViewport(viewport);
        offenders=[offenders overlapAcrossTabPages( ...
            viewport,tabs(tabIndex))]; %#ok<AGROW>
    end
    clear restore
end
end

function settleViewport(viewport)
content=viewport.Content.Root;
if isempty(content)||~isvalid(content),return,end
position=content.Position;
if any(~isfinite(position))||any(position(3:4)<=1)
    drawnow nocallbacks;return
end
nudged=position;nudged(3:4)=position(3:4)-1;
content.Position=nudged;drawnow nocallbacks
if isempty(content)||~isvalid(content),return,end
content.Position=position;drawnow nocallbacks
end

function groups=topLevelTabGroups(container)
groups={};handles=findall(container);
for index=1:numel(handles)
    candidate=handles(index);
    if isa(candidate,'matlab.ui.container.TabGroup')&& ...
            ~hasTabGroupAncestor(candidate,container)
        groups{end+1}=candidate; %#ok<AGROW>
    end
end
end

function value=hasTabGroupAncestor(candidate,container)
value=false;current=candidate.Parent;
while ~isempty(current)&&isvalid(current)&&~isequal(current,container)
    if isa(current,'matlab.ui.container.TabGroup')
        value=true;return
    end
    if ~isprop(current,'Parent'),return,end
    current=current.Parent;
end
end

function restoreSelectedTab(group,selected)
if ~isempty(group)&&isvalid(group)&&~isempty(selected)&&isvalid(selected)
    group.SelectedTab=selected;drawnow;
end
end

function value=isUIControl(handle)
value=strncmp(class(handle),'matlab.ui.control.',18);
end

function value=hasAxesAncestor(handle,root)
value=false;current=handle;
while ~isempty(current)&&isvalid(current)&&~isequal(current,root)
    if ~isequal(current,handle)&&isgraphics(current,'axes')
        value=true;return
    end
    if ~isprop(current,'Parent'),return,end
    current=current.Parent;
end
end

function value=layoutFitsGrid(control,parent)
value=false;
try
    [firstRow,lastRow]=layoutSpan(control.Layout.Row);
    [firstColumn,lastColumn]=layoutSpan(control.Layout.Column);
    value=firstRow>=1&&lastRow<=numel(parent.RowHeight)&& ...
        firstColumn>=1&&lastColumn<=numel(parent.ColumnWidth);
catch
end
end

function value=layoutCellsOverlap(first,second)
value=false;
try
    [firstRow,lastRow]=layoutSpan(first.Layout.Row);
    [firstColumn,lastColumn]=layoutSpan(first.Layout.Column);
    [secondRow,secondLastRow]=layoutSpan(second.Layout.Row);
    [secondColumn,secondLastColumn]=layoutSpan(second.Layout.Column);
    value=firstRow<=secondLastRow&&secondRow<=lastRow&& ...
        firstColumn<=secondLastColumn&&secondColumn<=lastColumn;
catch
end
end

function [first,last]=layoutSpan(value)
if isempty(value),first=0;last=0;return,end
first=value(1);last=value(end);
end

function value=controlName(handle)
value='';if isprop(handle,'Tag'),value=char(handle.Tag);end
if isempty(value),value=class(handle);end
end

function value=rectanglesOverlap(first,second,tolerance)
if any(~isfinite([first second]))||any(first(3:4)<=0)||any(second(3:4)<=0)
    value=false;return
end
horizontal=min(first(1)+first(3),second(1)+second(3))- ...
    max(first(1),second(1));
vertical=min(first(2)+first(4),second(2)+second(4))- ...
    max(first(2),second(2));
value=horizontal>tolerance&&vertical>tolerance;
end

function value=overlapName(label,control)
labelText='label';controlText=class(control);
try
    labelText=char(label.Text);
catch
end
if isprop(control,'Tag')&&~isempty(control.Tag)
    controlText=char(control.Tag);
end
value=[labelText ' -> ' controlText];
end
