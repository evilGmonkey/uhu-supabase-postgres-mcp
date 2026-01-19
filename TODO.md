# TODO: Multi-Database Support

## Overview
Expand the MCP server to support multiple database types beyond PostgreSQL/Supabase, enabling broader adoption across different technology stacks and organizational environments.

## Target Databases
- MySQL
- MariaDB
- Microsoft SQL Server (MSSQL)

## Strategic Value
- **Market Expansion**: Tap into MySQL/MariaDB (web hosting, SMB) and MSSQL (enterprise/.NET) user bases
- **Broader MCP Adoption**: Enable unified database interface across heterogeneous environments
- **n8n Integration Value**: Support for multiple database types in workflow automation
- **Technical Feasibility**: Current architecture is modular enough to support abstraction

## Suggested Phasing

### Phase 1: MySQL/MariaDB Support
**Priority: High**
**Rationale**: Similar to PostgreSQL philosophically, huge user base, relatively straightforward implementation

**Tasks:**
1. Add MySQL connection driver (mysql-connector-python or pymysql)
2. Create MySQL-specific setup scripts for role creation
   - Adapt to MySQL's user@host permission model
   - Handle GRANT syntax differences
3. Implement MySQL schema introspection
   - Adapt information_schema queries for MySQL differences
   - Handle MySQL-specific data types
4. Add MySQL connection string parsing and validation
5. Create MySQL-specific test suite
6. Update documentation with MySQL setup instructions
7. Add MySQL example to .env.example

**Key Differences to Handle:**
- User@host permission model vs PostgreSQL roles
- GRANT syntax variations
- information_schema differences
- Connection string format differences

### Phase 2: MSSQL Support
**Priority: Medium**
**Rationale**: Different paradigm, enterprise focus, requires more significant adaptation

**Tasks:**
1. Add MSSQL connection driver (pymssql or pyodbc)
2. Create MSSQL-specific setup scripts
   - Handle login/user separation model
   - Implement schema-based permissions
3. Implement MSSQL schema introspection
   - Use sys.tables, sys.columns instead of information_schema
   - Handle MSSQL-specific data types
4. Add MSSQL connection string parsing (different format)
5. Handle Windows authentication option
6. Create MSSQL-specific test suite
7. Update documentation with MSSQL setup instructions
8. Add MSSQL example to .env.example

**Key Differences to Handle:**
- Login vs User separation
- Schema-based permissions
- sys.* catalog views vs information_schema
- Connection string format (ODBC-style)
- Windows vs SQL authentication modes

## Technical Implementation Notes

### Code Changes Required

**1. Connection Management (server.py lines 147-165)**
- Add database type detection from connection string or explicit parameter
- Factory pattern for connection creation by database type
- Abstract connection pooling per database type

**2. Query Execution**
- Maintain current interface
- Handle dialect-specific SQL where necessary
- Keep PostgreSQL as reference implementation with most features

**3. Schema Introspection**
- Create database-specific adapters for:
  - list_tables
  - list_columns
  - list_schemas
- Abstract common interface

**4. Setup Scripts**
- Keep separate setup-{database}-roles.sh for each type
- Maintain consistent CLI interface across all scripts
- Document permission model differences clearly

**5. Configuration**
- Add optional DB_TYPE parameter to connection config
- Auto-detect from connection string where possible
- Update .env.example with examples for each database type

### Testing Strategy
- Maintain separate Docker Compose profiles for each database type
- Create database-specific test suites
- Ensure feature parity testing across databases
- Document known limitations per database type

### Documentation Updates
- Quick start guide per database type
- Permission model comparison table
- Feature compatibility matrix
- Migration guide for switching between database types

## Challenges to Address

**1. Permission Model Differences**
- PostgreSQL: Roles with GRANT/REVOKE
- MySQL: user@host with GRANT
- MSSQL: Login/User separation with schema permissions

**2. Feature Parity Decisions**
- Option A: Lowest common denominator (simpler, fewer features)
- Option B: Database-specific features exposed (complex, more powerful)
- **Recommended**: Start with common denominator, add database-specific features incrementally

**3. Maintenance Burden**
- Multiple database versions to support
- Different upgrade paths and breaking changes
- Increased testing surface area
- **Mitigation**: Automated testing, clear support matrix

**4. Schema Introspection Variations**
- information_schema standardization is imperfect
- Database-specific catalog views needed for advanced features
- **Solution**: Adapter pattern with fallbacks

## Success Criteria
- [ ] All three database types connect successfully
- [ ] Read-only and read-write roles work correctly for each type
- [ ] Schema introspection returns consistent results across databases
- [ ] Setup scripts successfully create roles with appropriate permissions
- [ ] Documentation clearly explains differences and setup per database
- [ ] Test coverage for each database type
- [ ] n8n integration works with all database types
- [ ] Performance acceptable across all database types

## Future Considerations
- SQLite support for local/embedded use cases?
- Oracle support for large enterprise environments?
- NoSQL databases (MongoDB, etc.) - would require different approach
- Database-specific optimizations and features

## Timeline Estimate
- **Phase 1 (MySQL/MariaDB)**: 2-3 weeks development + testing
- **Phase 2 (MSSQL)**: 2-3 weeks development + testing
- **Documentation & Polish**: 1 week

**Total**: ~6-8 weeks for full multi-database support

## Notes
Keep PostgreSQL as the most feature-rich implementation. Other databases should reach feature parity gradually, prioritizing core functionality first.
