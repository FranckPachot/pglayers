-- DocumentDB integration tests
-- Requires: shared_preload_libraries = 'pg_cron,pg_documentdb_core,pg_documentdb'

-- Test 1: Verify documentdb_core extension is available
SELECT CASE
    WHEN EXISTS (
        SELECT 1 FROM pg_available_extensions WHERE name = 'documentdb_core'
    )
    THEN 'PASS documentdb: documentdb_core extension available'
    ELSE 'FAIL documentdb: documentdb_core extension available'
END;

CREATE EXTENSION IF NOT EXISTS documentdb_core CASCADE;

-- Test 2: Create documentdb extension and verify it is loaded
CREATE EXTENSION IF NOT EXISTS documentdb CASCADE;
SELECT CASE
    WHEN EXISTS (
        SELECT 1 FROM pg_extension WHERE extname = 'documentdb'
    )
    THEN 'PASS documentdb: documentdb extension loaded'
    ELSE 'FAIL documentdb: documentdb extension loaded'
END;

-- Test 3: Insert and retrieve a document
SELECT documentdb_api.insert_one('testdb', 'testcollection',
    '{"_id": "test1", "name": "pglayers", "version": 1}'::documentdb_core.bson);

SELECT CASE
    WHEN (
        SELECT document->>'name'
        FROM documentdb_api_catalog.documentdb_api_catalog_search_documents('testdb', 'testcollection',
            '{"_id": "test1"}'::documentdb_core.bson)
        LIMIT 1
    ) = 'pglayers'
    THEN 'PASS documentdb: insert and retrieve document'
    ELSE 'FAIL documentdb: insert and retrieve document'
END;

-- Cleanup
SELECT documentdb_api.drop_collection('testdb', 'testcollection');
