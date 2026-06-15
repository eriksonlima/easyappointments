<?php defined('BASEPATH') or exit('No direct script access allowed');

/* ----------------------------------------------------------------------------
 * Easy!Appointments - Online Appointment Scheduler
 *
 * @package     EasyAppointments
 * @author      A.Tselegidis <alextselegidis@gmail.com>
 * @copyright   Copyright (c) Alex Tselegidis
 * @license     https://opensource.org/licenses/GPL-3.0 - GPLv3
 * @link        https://easyappointments.org
 * @since       v1.6.0
 * ---------------------------------------------------------------------------- */

/**
 * Companies model.
 *
 * Handles all the database operations of the company resource.
 *
 * @package Models
 */
class Companies_model extends EA_Model
{
    /**
     * @var array
     */
    protected array $casts = [
        'id' => 'integer',
        'is_private' => 'boolean',
    ];

    /**
     * @var array
     */
    protected array $api_resource = [
        'id' => 'id',
        'name' => 'name',
        'slug' => 'slug',
        'description' => 'description',
        'address' => 'address',
        'city' => 'city',
        'state' => 'state',
        'zip' => 'zip_code',
        'phone' => 'phone_number',
        'email' => 'email',
        'notes' => 'notes',
        'logo' => 'logo',
        'timezone' => 'timezone',
        'language' => 'language',
        'isPrivate' => 'is_private',
    ];

    /**
     * Save (insert or update) a company.
     *
     * @param array $company Associative array with the company data.
     *
     * @return int Returns the company ID.
     *
     * @throws InvalidArgumentException
     */
    public function save(array $company): int
    {
        $this->validate($company);

        if (empty($company['id'])) {
            return $this->insert($company);
        } else {
            return $this->update($company);
        }
    }

    /**
     * Validate the company data.
     *
     * @param array $company Associative array with the company data.
     *
     * @throws InvalidArgumentException
     */
    public function validate(array $company): void
    {
        if (!empty($company['id'])) {
            $count = $this->db->get_where('companies', ['id' => $company['id']])->num_rows();

            if (!$count) {
                throw new InvalidArgumentException(
                    'The provided company ID does not exist in the database: ' . $company['id'],
                );
            }
        }

        if (empty($company['name'])) {
            throw new InvalidArgumentException('Not all required fields are provided: ' . print_r($company, true));
        }

        if (!empty($company['email']) && !filter_var($company['email'], FILTER_VALIDATE_EMAIL)) {
            throw new InvalidArgumentException('Invalid email address provided: ' . $company['email']);
        }

        // Ensure slug uniqueness.
        if (!empty($company['slug'])) {
            $company_id = $company['id'] ?? null;

            $count = $this->db
                ->from('companies')
                ->where('slug', $company['slug'])
                ->where('id !=', $company_id)
                ->get()
                ->num_rows();

            if ($count > 0) {
                throw new InvalidArgumentException(
                    'The provided slug is already in use, please use a different one.',
                );
            }
        }
    }

    /**
     * Insert a new company into the database.
     *
     * @param array $company Associative array with the company data.
     *
     * @return int Returns the company ID.
     *
     * @throws RuntimeException
     */
    protected function insert(array $company): int
    {
        $company['create_datetime'] = date('Y-m-d H:i:s');
        $company['update_datetime'] = date('Y-m-d H:i:s');

        if (empty($company['slug']) && !empty($company['name'])) {
            $company['slug'] = $this->generate_slug($company['name']);
        }

        $provider_ids = $company['providers'] ?? [];

        unset($company['providers']);

        if (!$this->db->insert('companies', $company)) {
            throw new RuntimeException('Could not insert company.');
        }

        $company_id = $this->db->insert_id();

        $this->set_provider_ids($company_id, $provider_ids);

        return $company_id;
    }

    /**
     * Update an existing company.
     *
     * @param array $company Associative array with the company data.
     *
     * @return int Returns the company ID.
     *
     * @throws RuntimeException
     */
    protected function update(array $company): int
    {
        $company['update_datetime'] = date('Y-m-d H:i:s');

        $provider_ids = $company['providers'] ?? null;

        unset($company['providers']);

        if (!$this->db->update('companies', $company, ['id' => $company['id']])) {
            throw new RuntimeException('Could not update company.');
        }

        if ($provider_ids !== null) {
            $this->set_provider_ids($company['id'], $provider_ids);
        }

        return $company['id'];
    }

    /**
     * Remove an existing company from the database.
     *
     * @param int $company_id Company ID.
     *
     * @throws RuntimeException
     */
    public function delete(int $company_id): void
    {
        $this->db->delete('companies', ['id' => $company_id]);
    }

    /**
     * Get a specific company from the database.
     *
     * @param int $company_id The ID of the record to be returned.
     *
     * @return array Returns an array with the company data.
     *
     * @throws InvalidArgumentException
     */
    public function find(int $company_id): array
    {
        $company = $this->db->get_where('companies', ['id' => $company_id])->row_array();

        if (!$company) {
            throw new InvalidArgumentException(
                'The provided company ID was not found in the database: ' . $company_id,
            );
        }

        $this->cast($company);
        $company['providers'] = $this->get_provider_ids($company_id);

        return $company;
    }

    /**
     * Find a company by its slug.
     *
     * @param string $slug Company slug.
     *
     * @return array|null Returns the company array or null if not found.
     */
    public function find_by_slug(string $slug): ?array
    {
        $company = $this->db->get_where('companies', ['slug' => $slug])->row_array();

        if (!$company) {
            return null;
        }

        $this->cast($company);
        $company['providers'] = $this->get_provider_ids((int) $company['id']);

        return $company;
    }

    /**
     * Get all companies that match the provided criteria.
     *
     * @param array|string|null $where Where conditions
     * @param int|null $limit Record limit.
     * @param int|null $offset Record offset.
     * @param string|null $order_by Order by.
     *
     * @return array Returns an array of companies.
     */
    public function get(
        array|string|null $where = null,
        ?int $limit = null,
        ?int $offset = null,
        ?string $order_by = null,
    ): array {
        if ($where !== null) {
            $this->db->where($where);
        }

        if ($order_by !== null) {
            $this->db->order_by($this->quote_order_by($order_by));
        }

        $companies = $this->db->get('companies', $limit, $offset)->result_array();

        foreach ($companies as &$company) {
            $this->cast($company);
            $company['providers'] = $this->get_provider_ids((int) $company['id']);
        }

        return $companies;
    }

    /**
     * Get the query builder interface, configured for use with the companies table.
     *
     * @return CI_DB_query_builder
     */
    public function query(): CI_DB_query_builder
    {
        return $this->db->from('companies');
    }

    /**
     * Search companies by the provided keyword.
     *
     * @param string $keyword Search keyword.
     * @param int|null $limit Record limit.
     * @param int|null $offset Record offset.
     * @param string|null $order_by Order by.
     *
     * @return array Returns an array of companies.
     */
    public function search(string $keyword, ?int $limit = null, ?int $offset = null, ?string $order_by = null): array
    {
        $companies = $this->db
            ->select()
            ->from('companies')
            ->group_start()
            ->like('name', $keyword)
            ->or_like('description', $keyword)
            ->or_like('email', $keyword)
            ->or_like('phone_number', $keyword)
            ->or_like('address', $keyword)
            ->or_like('city', $keyword)
            ->or_like('state', $keyword)
            ->group_end()
            ->limit($limit)
            ->offset($offset)
            ->order_by($this->quote_order_by($order_by))
            ->get()
            ->result_array();

        foreach ($companies as &$company) {
            $this->cast($company);
        }

        return $companies;
    }

    /**
     * Get companies as options for dropdowns.
     *
     * @param array|string|null $where Where conditions.
     *
     * @return array Returns an array of options with 'value' and 'label' keys.
     */
    public function to_options(array|string|null $where = null): array
    {
        if ($where !== null) {
            $this->db->where($where);
        }

        $companies = $this->db->select('id, name')->from('companies')->order_by('name')->get()->result_array();

        $options = [];

        foreach ($companies as $company) {
            $options[] = [
                'value' => (int) $company['id'],
                'label' => $company['name'],
            ];
        }

        return $options;
    }

    /**
     * Get the provider IDs linked to a company.
     *
     * @param int $company_id Company ID.
     *
     * @return array Returns an array of provider IDs.
     */
    public function get_provider_ids(int $company_id): array
    {
        $rows = $this->db->get_where('company_providers', ['id_companies' => $company_id])->result_array();

        return array_map(fn($row) => (int) $row['id_users_provider'], $rows);
    }

    /**
     * Set the provider IDs linked to a company (replaces existing), preserving working_plan data.
     *
     * @param int $company_id Company ID.
     * @param array $provider_ids Provider IDs.
     */
    public function set_provider_ids(int $company_id, array $provider_ids): void
    {
        $provider_ids = array_map('intval', $provider_ids);

        // Remove providers no longer linked, preserving rows for still-linked providers.
        if (!empty($provider_ids)) {
            $this->db
                ->where('id_companies', $company_id)
                ->where_not_in('id_users_provider', $provider_ids)
                ->delete('company_providers');
        } else {
            $this->db->delete('company_providers', ['id_companies' => $company_id]);
        }

        // Insert only providers not yet in the table to avoid overwriting working_plan.
        foreach ($provider_ids as $provider_id) {
            $exists = $this->db
                ->get_where('company_providers', [
                    'id_companies' => $company_id,
                    'id_users_provider' => $provider_id,
                ])
                ->num_rows();

            if (!$exists) {
                $this->db->insert('company_providers', [
                    'id_companies' => $company_id,
                    'id_users_provider' => $provider_id,
                ]);
            }
        }
    }

    /**
     * Get the working plan for a provider in the context of this company.
     *
     * @param int $company_id Company ID.
     * @param int $provider_id Provider ID.
     *
     * @return string|null Returns the working plan JSON or null.
     */
    public function get_provider_working_plan(int $company_id, int $provider_id): ?string
    {
        $row = $this->db
            ->get_where('company_providers', [
                'id_companies' => $company_id,
                'id_users_provider' => $provider_id,
            ])
            ->row_array();

        return $row['working_plan'] ?? null;
    }

    /**
     * Set the working plan for a provider in the context of this company.
     *
     * @param int $company_id Company ID.
     * @param int $provider_id Provider ID.
     * @param string $working_plan Working plan JSON.
     */
    public function set_provider_working_plan(int $company_id, int $provider_id, string $working_plan): void
    {
        $existing = $this->db
            ->get_where('company_providers', [
                'id_companies' => $company_id,
                'id_users_provider' => $provider_id,
            ])
            ->num_rows();

        if ($existing) {
            $this->db->update(
                'company_providers',
                ['working_plan' => $working_plan],
                ['id_companies' => $company_id, 'id_users_provider' => $provider_id],
            );
        } else {
            $this->db->insert('company_providers', [
                'id_companies' => $company_id,
                'id_users_provider' => $provider_id,
                'working_plan' => $working_plan,
            ]);
        }
    }

    /**
     * Get all companies the given admin user manages.
     *
     * @param int $admin_id Admin user ID.
     *
     * @return array Returns an array of company IDs.
     */
    public function get_company_ids_for_admin(int $admin_id): array
    {
        $rows = $this->db->get_where('company_admins', ['id_users_admin' => $admin_id])->result_array();

        return array_map(fn($row) => (int) $row['id_companies'], $rows);
    }

    /**
     * Get all companies the given secretary manages.
     *
     * @param int $secretary_id Secretary user ID.
     *
     * @return array Returns an array of company IDs.
     */
    public function get_company_ids_for_secretary(int $secretary_id): array
    {
        $rows = $this->db->get_where('secretaries_companies', ['id_users_secretary' => $secretary_id])->result_array();

        return array_map(fn($row) => (int) $row['id_companies'], $rows);
    }

    /**
     * Assign a company admin user.
     *
     * @param int $company_id Company ID.
     * @param int $admin_id Admin user ID.
     */
    public function add_admin(int $company_id, int $admin_id): void
    {
        $existing = $this->db
            ->get_where('company_admins', ['id_companies' => $company_id, 'id_users_admin' => $admin_id])
            ->num_rows();

        if (!$existing) {
            $this->db->insert('company_admins', [
                'id_companies' => $company_id,
                'id_users_admin' => $admin_id,
            ]);
        }
    }

    /**
     * Remove a company admin user.
     *
     * @param int $company_id Company ID.
     * @param int $admin_id Admin user ID.
     */
    public function remove_admin(int $company_id, int $admin_id): void
    {
        $this->db->delete('company_admins', ['id_companies' => $company_id, 'id_users_admin' => $admin_id]);
    }

    /**
     * Get a specific field value from the database.
     *
     * @param int $company_id Company ID.
     * @param string $field Field name.
     *
     * @return mixed
     */
    public function value(int $company_id, string $field): mixed
    {
        $company = $this->db->get_where('companies', ['id' => $company_id])->row_array();

        if (!$company) {
            throw new InvalidArgumentException(
                'The provided company ID was not found in the database: ' . $company_id,
            );
        }

        $this->cast($company);

        if (!array_key_exists($field, $company)) {
            throw new InvalidArgumentException('The requested field was not found in the company data: ' . $field);
        }

        return $company[$field];
    }

    /**
     * Generate a URL-friendly slug from a company name.
     *
     * @param string $name Company name.
     *
     * @return string Returns a unique slug.
     */
    public function generate_slug(string $name): string
    {
        $base = strtolower(preg_replace('/[^a-z0-9]+/i', '-', $name));
        $base = trim($base, '-');
        $slug = $base;
        $i = 1;

        while ($this->db->get_where('companies', ['slug' => $slug])->num_rows() > 0) {
            $slug = $base . '-' . $i++;
        }

        return $slug;
    }

    /**
     * Convert the database company record to the equivalent API resource.
     *
     * @param array $company Company data.
     */
    public function api_encode(array &$company): void
    {
        $encoded_resource = [
            'id' => array_key_exists('id', $company) ? (int) $company['id'] : null,
            'name' => $company['name'],
            'slug' => $company['slug'],
            'description' => $company['description'],
            'address' => $company['address'],
            'city' => $company['city'],
            'state' => $company['state'],
            'zip' => $company['zip_code'],
            'phone' => $company['phone_number'],
            'email' => $company['email'],
            'notes' => $company['notes'],
            'logo' => $company['logo'],
            'timezone' => $company['timezone'],
            'language' => $company['language'],
            'isPrivate' => (bool) $company['is_private'],
        ];

        if (array_key_exists('providers', $company)) {
            $encoded_resource['providers'] = $company['providers'];
        }

        $company = $encoded_resource;
    }

    /**
     * Convert the API resource to the equivalent database company record.
     *
     * @param array $company API resource.
     * @param array|null $base Base company data to be overwritten with the provided values (useful for updates).
     */
    public function api_decode(array &$company, ?array $base = null): void
    {
        $decoded_resource = $base ?: [];

        $field_map = [
            'id' => 'id',
            'name' => 'name',
            'slug' => 'slug',
            'description' => 'description',
            'address' => 'address',
            'city' => 'city',
            'state' => 'state',
            'timezone' => 'timezone',
            'language' => 'language',
            'notes' => 'notes',
            'logo' => 'logo',
            'email' => 'email',
            'providers' => 'providers',
        ];

        foreach ($field_map as $api_key => $db_key) {
            if (array_key_exists($api_key, $company)) {
                $decoded_resource[$db_key] = $company[$api_key];
            }
        }

        if (array_key_exists('zip', $company)) {
            $decoded_resource['zip_code'] = $company['zip'];
        }

        if (array_key_exists('phone', $company)) {
            $decoded_resource['phone_number'] = $company['phone'];
        }

        if (array_key_exists('isPrivate', $company)) {
            $decoded_resource['is_private'] = (bool) $company['isPrivate'];
        }

        $company = $decoded_resource;
    }

    /**
     * Get all working plans for a provider across all companies (excluding one) and their particular plan.
     *
     * Returns an associative array:
     *   ['company:{id}' => [...plan...], 'particular' => [...plan...]]
     *
     * @param int      $provider_id        Provider user ID.
     * @param int|null $exclude_company_id Company ID to exclude (the one being edited).
     *
     * @return array
     */
    public function get_all_provider_working_plans(int $provider_id, ?int $exclude_company_id = null): array
    {
        $plans = [];

        $rows = $this->db
            ->where('id_users_provider', $provider_id)
            ->where('working_plan IS NOT NULL')
            ->get('company_providers')
            ->result_array();

        foreach ($rows as $row) {
            $company_id = (int) $row['id_companies'];

            if ($exclude_company_id !== null && $company_id === $exclude_company_id) {
                continue;
            }

            $plan = json_decode($row['working_plan'], true);

            if (is_array($plan)) {
                $company = $this->db->get_where('companies', ['id' => $company_id])->row_array();
                $label = $company ? $company['name'] : 'Company #' . $company_id;

                $plans['company:' . $company_id] = [
                    'label' => $label,
                    'plan' => $plan,
                ];
            }
        }

        $user_settings = $this->db
            ->get_where('user_settings', ['id_users' => $provider_id])
            ->row_array();

        if (!empty($user_settings['working_plan'])) {
            $particular_plan = json_decode($user_settings['working_plan'], true);

            if (is_array($particular_plan)) {
                $plans['particular'] = [
                    'label' => 'Particular',
                    'plan' => $particular_plan,
                ];
            }
        }

        return $plans;
    }

    /**
     * Check if a proposed working plan conflicts with the provider's existing plans.
     *
     * Two time ranges conflict when: newStart < existingEnd AND newEnd > existingStart.
     *
     * @param int      $provider_id        Provider user ID.
     * @param array    $new_plan           Proposed working plan (decoded JSON array keyed by day).
     * @param int|null $exclude_company_id Exclude this company when gathering existing plans (the one being saved).
     *
     * @return array  Returns an empty array if no conflicts, or an array of conflict descriptions.
     */
    public function find_working_plan_conflicts(int $provider_id, array $new_plan, ?int $exclude_company_id = null): array
    {
        $conflicts = [];
        $existing_plans = $this->get_all_provider_working_plans($provider_id, $exclude_company_id);

        $days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];

        foreach ($days as $day) {
            $new_day = $new_plan[$day] ?? null;

            if (empty($new_day) || empty($new_day['start']) || empty($new_day['end'])) {
                continue;
            }

            $new_start = strtotime($new_day['start']);
            $new_end = strtotime($new_day['end']);

            foreach ($existing_plans as $key => $entry) {
                $existing_day = $entry['plan'][$day] ?? null;

                if (empty($existing_day) || empty($existing_day['start']) || empty($existing_day['end'])) {
                    continue;
                }

                $ex_start = strtotime($existing_day['start']);
                $ex_end = strtotime($existing_day['end']);

                if ($new_start < $ex_end && $new_end > $ex_start) {
                    $conflicts[] = [
                        'day' => $day,
                        'context' => $entry['label'],
                        'existing' => $existing_day['start'] . '–' . $existing_day['end'],
                        'proposed' => $new_day['start'] . '–' . $new_day['end'],
                    ];
                }
            }
        }

        return $conflicts;
    }
}
