# Stripe Tax Analyzer

A web application for processing and analyzing Stripe payout and transaction data, designed to help categorize transactions by region (EU vs non-EU), calculate income and fees summaries, and identify missing or irregular items.

## Technical Stack

### Backend
- **Rails 8.0.4** - Ruby web framework
- **PostgreSQL** - Database
- **Inertia Rails** - Server-side adapter for Inertia.js
- **Solid Queue** - Job processing
- **Solid Cache** - Caching layer

### Frontend
- **React 19.2.0** - UI library
- **TypeScript** - Type-safe JavaScript
- **Tailwind CSS 4.1.17** - Utility-first CSS framework
- **DaisyUI 5.1.1** - Component library for Tailwind CSS
- **Inertia.js** - Modern monolith approach (React + Rails)

### Build Tools
- **Vite** - Next-generation frontend tooling
- **Vite Rails** - Rails integration for Vite

## Project Purpose

This application solves a specific problem with Stripe payout data processing:

### The Problem

Each month, you receive a payout from Stripe. You can export two types of CSV files:

1. **Payout CSV**: Contains a list of transaction IDs for a payout period, but lacks crucial detailed information needed for tax and accounting purposes.

2. **Transactions CSV**: Contains detailed transaction information with all the data you need, but needs to be matched up with the payout period.

### The Solution

The application:

1. **Accepts Two Upload Types**:
   - **Payout CSV**: Upload the payout period CSV containing transaction IDs
   - **Transactions CSV**: Upload the detailed transactions CSV with full transaction data

2. **Matches Transactions**: Automatically matches transaction IDs from the payout CSV with the detailed transaction data from the transactions CSV.

3. **Categorizes by Region**: Identifies which transactions are EU-based and which are non-EU, enabling proper tax categorization.

4. **Summarizes Financial Data**: Calculates and displays:
   - Total income for EU transactions
   - Total income for non-EU transactions
   - Total fees for EU transactions
   - Total fees for non-EU transactions

5. **Persists Data**: Saves all processed information to the database for future reference and historical tracking.

6. **Displays Results**: Presents all data in a clean, modern UI built with React and DaisyUI.

7. **Detects Irregularities**: Identifies and flags:
   - Missing transactions (transaction IDs in payout CSV that don't match any in transactions CSV)
   - Irregular items that may need manual review

### Workflow

1. Upload the **payout CSV** - This creates a payout period/area in the system
2. Upload the **transactions CSV** - This provides the detailed data needed
3. The system automatically matches transactions and categorizes them
4. View summaries, detailed breakdowns, and any irregularities in the UI
5. All data is saved for historical reference

## Setup Instructions

### Prerequisites

- Ruby (compatible with Rails 8.0.4)
- PostgreSQL
- Node.js and npm

### Installation

1. **Clone the repository** (if applicable) or navigate to the project directory

2. **Install Ruby dependencies**:
   ```bash
   bundle install
   ```

3. **Install JavaScript dependencies**:
   ```bash
   npm install
   ```

4. **Set up the database**:
   ```bash
   rails db:create
   rails db:migrate
   ```

5. **Start the development server**:
   ```bash
   bin/dev
   ```

   This will start both the Rails server and Vite dev server concurrently.

### Development

The application uses Rails with Inertia.js, so you'll be working with:

- **Backend**: Ruby on Rails controllers and models in `app/controllers/` and `app/models/`
- **Frontend**: React components in `app/frontend/pages/`
- **Styling**: Tailwind CSS classes with DaisyUI components

## Usage Instructions

### Uploading Data

1. **Navigate to the upload page** in the application

2. **Upload Payout CSV**:
   - Select your payout period CSV file
   - This file should contain transaction IDs for a specific payout period
   - The system will create a payout period record

3. **Upload Transactions CSV**:
   - Select your detailed transactions CSV file
   - This file should contain full transaction details including transaction IDs
   - The system will match these with the payout transaction IDs

### Viewing Results

After processing, you can:

- **View Summary**: See total income and fees broken down by EU and non-EU categories
- **View Details**: Browse individual transactions with their categorization
- **Check Irregularities**: Review any missing or irregular items that need attention
- **Access History**: View previously processed payout periods

### Data Management

- All processed data is automatically saved to the database
- You can view historical payout periods and their associated transactions
- The system maintains the relationship between payout periods and their transactions

## Development Notes

- The frontend is built with React and TypeScript for type safety
- UI components use DaisyUI for consistent, modern styling
- Tailwind CSS provides utility classes for custom styling
- Inertia.js handles the seamless integration between Rails and React without requiring a separate API
