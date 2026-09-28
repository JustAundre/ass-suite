# SQL Databases

## Basic Authentication

> [!NOTE]
>
> This section is not applicable to PostgreSQL.
> If you are following this for PostgreSQL,
> please skip to the [next section](#audit-authorization).

Run the `mysql_secure_installation` command and answer its prompts as needed.

This script covers the following:

- Set non-default password for SQL `root` user
- Disables remote login for the SQL `root` user
- Disables anonymous users
- Removes test databases and respective permissions

## Audit Authorization

1. List SQL users

	MySQL/MariaDB:

	```sql
	SELECT User, Host FROM mysql.user;
	```

	PostgreSQL:

	```sql
	SELECT usename FROM pg_user;
	```

2. Delete and adjust usernames and scoping as needed

	MySQL/MariaDB:

	```sql
	DROP USER 'username'@'host';

	RENAME USER 'old_user'@'old_host' TO 'new_user'@'new_host';
	```

	PostgreSQL:
	- Note: you need to reassign ownership of old_user to another user when deleting a SQL user in PostgreSQL using `REASSIGN OWNED BY username TO new_owner;`.

	```sql
	DROP USER username;

	ALTER USER old_user RENAME TO new_user;
	```

3. Review GRANTS

	MySQL/MariaDB:

	```sql
	SELECT grantee, privilege_type, table_schema, table_name
	FROM information_schema.user_privileges;
	```

	PostgreSQL:

	```sql
	SELECT grantee, table_schema, table_name, privilege_type
	FROM information_schema.table_privileges
	WHERE grantee NOT IN ('PUBLIC', 'postgres');
	```

4. Remove GRANTs as needed

	MySQL/MariaDB (from databases):

	```sql
	REVOKE SELECT, INSERT ON database_name.* FROM 'username'@'host';
	```
