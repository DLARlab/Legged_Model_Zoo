classdef ImageMetrics
    %IMAGEMETRICS Platform-tolerant comparisons for rendered graphics.
    methods (Static)
        function result=compare(reference,candidate)
            first=normalized(reference);second=normalized(candidate);
            if ~isequal(size(first),size(second))
                error('lmz:Graphics:ImageSize','Rendered images must have equal size.');
            end
            difference=first-second;
            nrmse=sqrt(mean(difference(:).^2));
            firstGray=gray(first);secondGray=gray(second);
            firstEdges=edgeMap(firstGray);secondEdges=edgeMap(secondGray);
            denominator=nnz(firstEdges)+nnz(secondEdges);
            if denominator==0,edgeOverlap=1;else
                edgeOverlap=2*nnz(firstEdges&secondEdges)/denominator;
            end
            firstBounds=bounds(firstGray);secondBounds=bounds(secondGray);
            boundingBoxAgreement=boxIntersection(firstBounds,secondBounds);
            colorClusterAgreement=histogramIntersection(first,second);
            structuralSimilarity=NaN;
            if exist('ssim','file')==2
                try
                    structuralSimilarity=ssim(secondGray,firstGray);
                catch
                end
            end
            result=struct('NormalizedRMSE',nrmse,'EdgeMapOverlap',edgeOverlap, ...
                'StructuralSimilarity',structuralSimilarity, ...
                'ForegroundBoundingBoxAgreement',boundingBoxAgreement, ...
                'ColorClusterAgreement',colorClusterAgreement, ...
                'ReferenceBounds',firstBounds,'CandidateBounds',secondBounds);
        end
    end
end

function value=normalized(value)
if ~isnumeric(value)||~isreal(value)||any(~isfinite(double(value(:))))
    error('lmz:Graphics:ImageType','Images must be finite real numeric arrays.');
end
integerInput=isinteger(value);inputClass=class(value);value=double(value);
if integerInput,value=value/double(intmax(inputClass));return,end
maximum=max(value(:));
if maximum>1,value=value/255;end
value=max(0,min(1,value));
end
function value=gray(imageData)
if ismatrix(imageData)
    value=imageData;
else
    value=mean(imageData(:,:,1:min(3,size(imageData,3))),3);
end
end
function value=edgeMap(imageData)
[horizontal,vertical]=gradient(imageData);
magnitude=sqrt(horizontal.^2+vertical.^2);
threshold=max(0.025,0.25*mean(magnitude(:))+0.5*std(magnitude(:)));
value=magnitude>threshold;
end
function value=bounds(imageData)
background=imageData>0.98;mask=~background;[rows,columns]=find(mask);
if isempty(rows),value=[0 0 0 0];else
    value=[min(columns) min(rows) max(columns) max(rows)];
end
end
function value=boxIntersection(first,second)
if all(first==0)&&all(second==0),value=1;return,end
left=max(first(1),second(1));top=max(first(2),second(2));
right=min(first(3),second(3));bottom=min(first(4),second(4));
intersection=max(0,right-left+1)*max(0,bottom-top+1);
firstArea=max(0,first(3)-first(1)+1)*max(0,first(4)-first(2)+1);
secondArea=max(0,second(3)-second(1)+1)*max(0,second(4)-second(2)+1);
union=firstArea+secondArea-intersection;
if union==0,value=1;else,value=intersection/union;end
end
function value=histogramIntersection(first,second)
bins=linspace(0,1,17);firstHistogram=zeros(1,16);secondHistogram=zeros(1,16);
for channel=1:size(first,3)
    firstHistogram=firstHistogram+histcounts(first(:,:,channel),bins);
    secondHistogram=secondHistogram+histcounts(second(:,:,channel),bins);
end
firstHistogram=firstHistogram/sum(firstHistogram);
secondHistogram=secondHistogram/sum(secondHistogram);
value=sum(min(firstHistogram,secondHistogram));
end
