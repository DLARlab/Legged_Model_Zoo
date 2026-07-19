classdef TestXAccumRoundTrip < matlab.unittest.TestCase
    methods (Test)
        function scientificDatasetsRoundTripExactly(testCase)
            catalog=lmzmodels.slip_quad_load.ScientificDatasetCatalog.default();
            records=catalog.records();
            for index=1:numel(records)
                dataset=catalog.load(records(index).id);
                decoded=lmzmodels.slip_quad_load.XAccumAdapter.decode(dataset.XAccum);
                testCase.verifyEqual(lmzmodels.slip_quad_load.XAccumAdapter.encode(decoded), ...
                    dataset.XAccum);
                packed=decoded.Schema.pack(decoded.Schema.unpack(dataset.XAccum));
                testCase.verifyEqual(packed,dataset.XAccum);
                path=[tempname '.mat'];cleanup=onCleanup(@()deleteIfPresent(path));
                lmzmodels.slip_quad_load.XAccumAdapter.exportLegacy(path,dataset);
                exported=load(path,'X_accum');testCase.verifyEqual(exported.X_accum,dataset.XAccum);
                clear cleanup
            end
        end
    end
end
function deleteIfPresent(path)
if exist(path,'file')==2,delete(path);end
end
