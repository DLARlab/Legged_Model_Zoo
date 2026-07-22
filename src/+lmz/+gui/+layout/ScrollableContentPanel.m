classdef ScrollableContentPanel < handle
    %SCROLLABLECONTENTPANEL Pixel-sized content hosted by a scroll viewport.
    properties (SetAccess=private)
        Root
        MinimumSize
    end

    methods
        function obj=ScrollableContentPanel(parent,minimumSize,tag)
            if nargin<2||isempty(minimumSize),minimumSize=[320 400];end
            if nargin<3,tag='lmz-scroll-content';end
            obj.MinimumSize=reshape(minimumSize,1,2);
            obj.Root=uipanel(parent,'BorderType','none','Tag',tag, ...
                'Position',[1 1 obj.MinimumSize]);
        end

        function resize(obj,availableSize)
            sizeValue=max(obj.MinimumSize,reshape(availableSize,1,2));
            obj.Root.Position=[1 1 sizeValue];
        end

        function setMinimumSize(obj,value)
            validateattributes(value,{'numeric'},{'numel',2,'finite','positive'});
            obj.MinimumSize=reshape(value,1,2);
        end

        function value=fitToControls(obj,floorSize)
            % Derive the scroll extent from rendered controls, including
            % every page of nested tab groups, instead of trusting a fixed
            % caller-supplied height. Grid tracks and child content provide
            % the minimum; the rendered-overflow pass handles backend-specific
            % decoration such as tab and panel headers.
            if nargin<2||isempty(floorSize),floorSize=[360 400];end
            validateattributes(floorSize,{'numeric'}, ...
                {'numel',2,'finite','positive'});
            floorSize=reshape(floorSize,1,2);
            % Reserve the small browser-side border/header delta that is not
            % represented in GridLayout track metadata.  This is a decoration
            % allowance, not a panel-specific scroll extent.
            required=containerMinimum(obj.Root)+[8 8];
            obj.MinimumSize=max([obj.MinimumSize;floorSize;ceil(required)], ...
                [],1);
            obj.Root.Position=[1 1 obj.MinimumSize];
            if canMeasureRenderedControls(obj.Root)
                obj.growForVisibleControls();
            end
            value=ceil(max(floorSize,obj.Root.Position(3:4)));
            obj.Root.Position=[1 1 value];
            obj.MinimumSize=value;
        end

        function delete(obj)
            if ~isempty(obj.Root)&&isvalid(obj.Root),delete(obj.Root);end
            obj.Root=[];
        end
    end


    methods (Access=private)
        function growForVisibleControls(obj)
            for iteration=1:8
                drawnow;
                overflow=visibleOverflow(obj.Root);
                if any(~isfinite(overflow))||all(overflow<=2),return,end
                current=obj.Root.Position(3:4);
                growth=[overflow(1)+overflow(3) ...
                    overflow(2)+overflow(4)];
                growth(growth>2)=growth(growth>2)+4;
                growth(growth<=2)=0;
                obj.Root.Position=[1 1 ceil(current+growth)];
            end
        end

    end
end

function overflow=visibleOverflow(root)
overflow=zeros(1,4);rootBounds=getpixelposition(root,true);
if any(~isfinite(rootBounds))||any(rootBounds(3:4)<=0),return,end
handles=findall(root);
for index=1:numel(handles)
    handle=handles(index);
    if isequal(handle,root)||~isprop(handle,'Position')|| ...
            ~effectivelyVisible(handle)||hasAxesAncestor(handle,root)
        continue
    end
    try
        bounds=getpixelposition(handle,true);
    catch
        continue
    end
    if any(~isfinite(bounds))||any(bounds(3:4)<=0),continue,end
    overflow=max(overflow,[max(0,rootBounds(1)-bounds(1)) ...
        max(0,rootBounds(2)-bounds(2)) ...
        max(0,sum(bounds([1 3]))-sum(rootBounds([1 3]))) ...
        max(0,sum(bounds([2 4]))-sum(rootBounds([2 4])))]);
end
end

function value=containerMinimum(handle)
if isa(handle,'matlab.ui.container.GridLayout')
    value=gridMinimum(handle);return
end
if isa(handle,'matlab.ui.container.TabGroup')
    value=[0 0];tabs=handle.Children;
    for index=1:numel(tabs)
        value=max(value,containerMinimum(tabs(index)));
    end
    value=value+[4 32];return
end
if isa(handle,'matlab.ui.container.Panel')|| ...
        isa(handle,'matlab.ui.container.Tab')
    value=[0 0];children=handle.Children;
    for index=1:numel(children)
        value=max(value,containerMinimum(children(index)));
    end
    if isa(handle,'matlab.ui.container.Panel')&& ...
            isprop(handle,'Title')&&~isempty(handle.Title)
        value=value+[8 30];
    else
        value=value+[4 4];
    end
    return
end
value=controlMinimum(handle);
end

function value=gridMinimum(grid)
rows=grid.RowHeight;columns=grid.ColumnWidth;
if ~iscell(rows),rows=num2cell(rows);end
if ~iscell(columns),columns=num2cell(columns);end
[rowMinimum,rowFlexible]=trackBases(rows,28);
[columnMinimum,columnFlexible]=trackBases(columns,72);
rowConstraints=struct('First',{},'Last',{},'Required',{});
columnConstraints=rowConstraints;
children=grid.Children;
for index=1:numel(children)
    child=children(index);required=containerMinimum(child);
    [firstRow,lastRow]=layoutSpan(child,'Row',numel(rows));
    [firstColumn,lastColumn]=layoutSpan(child,'Column',numel(columns));
    rowConstraints(end+1)=struct('First',firstRow,'Last',lastRow, ...
        'Required',required(2)); %#ok<AGROW>
    columnConstraints(end+1)=struct('First',firstColumn, ...
        'Last',lastColumn,'Required',required(1)); %#ok<AGROW>
end
rowMinimum=applyConstraints(rowMinimum,rowConstraints,grid.RowSpacing, ...
    rowFlexible);
columnMinimum=applyConstraints(columnMinimum,columnConstraints, ...
    grid.ColumnSpacing,columnFlexible);
padding=grid.Padding;
value=[sum(columnMinimum)+max(0,numel(columns)-1)*grid.ColumnSpacing+ ...
    padding(1)+padding(3), ...
    sum(rowMinimum)+max(0,numel(rows)-1)*grid.RowSpacing+ ...
    padding(2)+padding(4)];
end

function [value,flexible]=trackBases(specifications,flexibleMinimum)
value=zeros(1,numel(specifications));
flexible=false(1,numel(specifications));
for index=1:numel(specifications)
    specification=specifications{index};
    if isnumeric(specification)&&isscalar(specification)
        value(index)=specification;
    elseif ischar(specification)|| ...
            (isstring(specification)&&isscalar(specification))
        textValue=char(specification);
        flexible(index)=true;
        if ~strcmpi(textValue,'fit')
            value(index)=flexibleMinimum;
        end
    end
end
end

function [first,last]=layoutSpan(child,name,count)
first=1;last=count;
try
    value=child.Layout.(name);
    if isnumeric(value)&&~isempty(value)
        first=max(1,min(count,value(1)));
        last=max(first,min(count,value(end)));
    end
catch
end
end

function tracks=applyConstraints(tracks,constraints,spacing,flexible)
if isempty(constraints),return,end
span=arrayfun(@(item)item.Last-item.First,constraints);
[~,order]=sort(span);
for orderIndex=1:numel(order)
    item=constraints(order(orderIndex));indices=item.First:item.Last;
    available=sum(tracks(indices))+max(0,numel(indices)-1)*spacing;
    deficit=item.Required-available;
    if deficit>0
        adjustable=indices(flexible(indices));
        if isempty(adjustable),continue,end
        tracks(adjustable)=tracks(adjustable)+deficit/numel(adjustable);
    end
end
end

function value=controlMinimum(control)
value=[72 28];
if isgraphics(control,'axes'),value=[240 170];return,end
className=class(control);
if contains(className,'Table'),value=[280 140];return,end
if contains(className,'TextArea'),value=[220 90];return,end
if contains(className,'ListBox'),value=[180 90];return,end
if contains(className,'Tree'),value=[180 120];return,end
isLabel=contains(className,'.Label');
if isLabel,value=[24 22];end
textValue='';
if isprop(control,'Text')
    try
        textValue=flattenText(control.Text);
    catch
    end
elseif isprop(control,'Items')
    try
        items=control.Items;
        if isstring(items),items=cellstr(items);end
        if ischar(items),items={items};end
        if iscell(items)&&~isempty(items)
            lengths=cellfun(@(item)numel(char(item)),items);
            [~,selected]=max(lengths);textValue=char(items{selected});
        end
    catch
    end
end
if ~isempty(textValue)
    wrapped=false;
    if isprop(control,'WordWrap')
        try
            wrapped=strcmp(char(control.WordWrap),'on');
        catch
        end
    end
    [textWidth,textHeight]=textMinimum(textValue,wrapped&&isLabel);
    value=max(value,[textWidth textHeight]);
end
end

function value=flattenText(source)
if isstring(source),source=cellstr(source);end
if iscell(source)
    if isempty(source),value='';return,end
    source=cellfun(@char,source,'UniformOutput',false);
    value=strjoin(source,newline);return
end
value=char(source);
end

function [width,height]=textMinimum(value,wrapped)
lines=regexp(value,'\r\n|\n|\r','split');
if isempty(lines),lines={''};end
lengths=cellfun(@numel,lines);
if ~wrapped
    width=max(24,7*max([0 lengths])+24);
    height=max(22,18*numel(lines)+6);return
end
tokens=regexp(value,'\s+','split');
tokens=tokens(~cellfun(@isempty,tokens));
if isempty(tokens),longestWord=0;else,longestWord=max(cellfun(@numel,tokens));end
width=max(96,min(220,max(140,7*longestWord+24)));
charactersPerLine=max(1,floor((width-24)/7));
lineCount=sum(max(1,ceil(lengths/charactersPerLine)));
height=max(22,18*lineCount+6);
end

function value=effectivelyVisible(handle)
value=true;current=handle;
while ~isempty(current)&&isvalid(current)
    % Hidden figures are used for deterministic automated layout checks.
    % Treat the figure as the visibility boundary while still honoring all
    % locally hidden panels and selected-tab state beneath it.
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
    if ~isprop(current,'Parent'),return,end
    current=current.Parent;
end
end

function value=canMeasureRenderedControls(root)
value=false;
if isempty(root)||~isvalid(root)||isempty(root.Parent)||~isvalid(root.Parent)
    return
end
figureHandle=ancestor(root,'figure');
if isempty(figureHandle)||~isvalid(figureHandle)|| ...
        strcmp(char(figureHandle.Visible),'off')
    % Hidden UIFigures do not expose settled browser-side GridLayout child
    % positions.  The recursive structural estimator still sizes every tab;
    % the rendered overflow pass is reserved for an actually rendered view.
    return
end
try
    rootBounds=getpixelposition(root,true);
    parentBounds=getpixelposition(root.Parent,true);
catch
    return
end
value=all(isfinite([rootBounds parentBounds]))&& ...
    all(rootBounds(3:4)>0)&&all(parentBounds(3:4)>0);
end

function value=hasAxesAncestor(handle,root)
% Plot primitives use data coordinates, so only the axes container itself
% participates in UI extent measurement.
value=false;current=handle;
while ~isempty(current)&&isvalid(current)&&~isequal(current,root)
    if ~isequal(current,handle)&&isgraphics(current,'axes')
        value=true;return
    end
    if ~isprop(current,'Parent'),return,end
    current=current.Parent;
end
end
