# Groups Page Generation Prompt

Create a React Page "Groups" that:

## Core Requirements

- Calls a Power Pages Server Logic endpoint: `/_api/serverlogics/groups`
- Works for authenticated users only
- Shows a loading indicator during request
- Displays the group `displayName` and `id`
- Handles errors with a user-friendly message
- Uses React hooks and modern best practices
- Uses `webapi.ts` library to make the call with CSRF token

## Navigation

- Add the Groups page to the navigation inside `App.tsx`

## API Response Structure

The server logic endpoint returns the following data structure:

```json
{
  "requestId": "0757b001-5d86-4286-8a90-0e429317534f",
  "success": true,
  "data": "{\"status\":\"success\",\"userEmail\":\"user@example.com\",\"groups\":[{\"id\":\"5c310c07-1f83-458e-b6b0-d0349ac011f2\",\"displayName\":\"AddIns\"},{\"id\":\"aa7d9a15-8192-4ddf-bccd-d1b1035f2c7d\",\"displayName\":\"Death Star Publish Approvers\"}]}",
  "serverLogicName": "groups"
}
```

## Data Handling

- The `data` field is a JSON string that needs to be parsed
- After parsing, extract the `groups` array from the parsed object
- Filter out groups with null/undefined `displayName`
- Sort groups alphabetically by `displayName`

## Implementation Details

- Follow the same patterns as the existing `Accounts.tsx` page
- Include a refresh button to reload groups
- Display group count when loaded successfully
- Use inline styles consistent with the existing codebase
- Implement proper TypeScript interfaces for type safety
- Handle component cleanup to prevent memory leaks
