CREATE INDEX FOR (a:Author) ON (a.author_id);
CREATE INDEX FOR (p:Paper) ON (p.doi);

:auto LOAD CSV WITH HEADERS FROM "file:///authors.csv" AS row
WITH row 
WHERE row.authorId IS NOT NULL AND row.name IS NOT NULL AND row.doi IS NOT NULL
CALL {
    WITH row
    MERGE (author:Author {author_id: row.authorId})
    ON CREATE SET author.author_name = row.name, 
        author.author_doi = [row.doi]
    ON MATCH SET author.author_doi = coalesce(author.author_doi, []) + row.doi
} IN TRANSACTIONS;

:auto LOAD CSV WITH HEADERS FROM "file:///papers.csv" AS row
WITH row
WHERE row.doi IS NOT NULL AND row.title IS NOT NULL AND row.year IS NOT NULL
CALL {
    WITH row
    MERGE (paper:Paper {doi: row.doi})
    ON CREATE SET paper.title = row.title, 
                  paper.year = row.year
} IN TRANSACTIONS;


// This is inefficient, giving java heap space error
// MATCH (a:Author), (p:Paper)
// WHERE any(doi IN a.author_doi WHERE doi = p.doi)
// MERGE (a)-[:WROTE]->(p);
// This is more efficient, but still giving java heap space error
// MATCH (a:Author)
// UNWIND a.author_doi AS doi
// MATCH (p:Paper {doi: doi})
// MERGE (a)-[:WROTE]->(p);
CALL apoc.periodic.iterate(
    "MATCH (a:Author) WHERE size(a.author_doi) > 0 RETURN a",
    "UNWIND a.author_doi AS doi
     MATCH (p:Paper {doi: doi})
     MERGE (a)-[:WROTE]->(p)",
    {batchSize: 1000, parallel: false}
);


:auto LOAD CSV WITH HEADERS FROM "file:///references.csv" AS row
WITH row
WHERE row.paper_doi IS NOT NULL AND row.reference_doi IS NOT NULL
CALL {
    WITH row
    MATCH (p1:Paper {doi: row.paper_doi})
    MATCH (p2:Paper {doi: row.reference_doi})
    MERGE (p1)-[:CITES]->(p2)
} IN TRANSACTIONS;
