# GitHub Actions Deployment to OpenShift - Quick Start Guide

## Introduction

This guide provides step-by-step instructions for setting up automated deployments from GitHub to OpenShift Container Platform (OSE) using GitHub Actions. By implementing this CI/CD pipeline, you'll enable automatic deployments of your application whenever changes are pushed to your repository.

## Prerequisites

Before starting, ensure you have:

- An OpenShift Container Platform (OSE) account with appropriate permissions
- A GitHub repository containing your application code
- Basic familiarity with YAML syntax and containerization concepts

## Setup Process

### Step 1: Set up your OpenShift project

First, create or use an existing project in OpenShift:

1. Log in to your OpenShift Web Console
2. Create a new project or select an existing one
3. Take note of the project name (namespace)
4. Generate an access token with sufficient permissions for deployments

### Step 2: Create a GitHub repository

If you haven't already:

1. Create a new GitHub repository
2. Push your application code to this repository
3. Ensure your repository includes necessary deployment configuration files

### Step 3: Creating a GitHub Action Workflow

Set up the automated workflow in GitHub:

1. Navigate to your GitHub repository and access the "Actions" tab
2. Click "Set up a workflow yourself" or edit an existing workflow file
3. Create a new file at `.github/workflows/deploy-to-ose.yml`
4. Use the following template as a starting point:

```yaml
name: Deploy to OpenShift

env:
  OPENSHIFT_SERVER: ${{ secrets.OPENSHIFT_SERVER }}
  OPENSHIFT_TOKEN: ${{ secrets.OPENSHIFT_TOKEN }}
  OPENSHIFT_NAMESPACE: "your-project-name"

on:
  push:
    branches:
      - main

jobs:
  deploy:
    name: Deploy to OpenShift
    runs-on: ubuntu-latest
    steps:
      - name: Check out code
        uses: actions/checkout@v3

      - name: Install OpenShift CLI
        uses: redhat-actions/openshift-tools-installer@v1
        with:
          oc: 4

      - name: Log in to OpenShift
        uses: redhat-actions/oc-login@v1
        with:
          openshift_server_url: ${{ env.OPENSHIFT_SERVER }}
          openshift_token: ${{ env.OPENSHIFT_TOKEN }}
          insecure_skip_tls_verify: true
          namespace: ${{ env.OPENSHIFT_NAMESPACE }}

      - name: Deploy application
        run: |
          # Add your deployment commands here
          oc apply -f deployment/
```

### Step 4: Configuring GitHub Secrets

Secure your OpenShift credentials by setting up GitHub Secrets:

1. Go to your GitHub repository's "Settings" tab
2. Navigate to "Secrets" → "Actions"
3. Click "New repository secret"
4. Add the following secrets:
   - `OPENSHIFT_SERVER`: Your OpenShift cluster URL
   - `OPENSHIFT_TOKEN`: Your OpenShift authentication token
   - `OPENSHIFT_NAMESPACE`: Your project namespace (if not defined in workflow)

## Workflow Explanation

This GitHub Actions workflow:

1. Triggers whenever code is pushed to the main branch
2. Checks out your repository code
3. Installs the OpenShift CLI (oc)
4. Authenticates with your OpenShift cluster
5. Deploys your application using configurations in the `deployment/` directory

## Customization Options

You can extend this basic workflow to:

- Build and push container images to a registry
- Run tests before deployment
- Perform database migrations
- Deploy to different environments based on branches
- Add approval steps for production deployments

## Troubleshooting

If you encounter issues:

- Check the GitHub Actions logs for detailed error messages
- Verify your OpenShift credentials are correct and have appropriate permissions
- Ensure your deployment configuration files are valid
- Test commands locally using the OpenShift CLI before automating

## Conclusion

By following this guide, you've set up an automated CI/CD pipeline that deploys your application to OpenShift whenever changes are pushed to your GitHub repository. This streamlines your development workflow and ensures consistent deployments.

For more advanced configurations and options, refer to the official documentation for GitHub Actions and OpenShift.