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

class Migration_Insert_company_admin_role extends EA_Migration
{
    /**
     * Upgrade method.
     */
    public function up(): void
    {
        $existing = $this->db->get_where('roles', ['slug' => 'company_admin'])->row_array();

        if (empty($existing)) {
            $this->db->insert('roles', [
                'name' => 'Company Admin',
                'slug' => 'company_admin',
                'is_admin' => false,
                'appointments' => 15,
                'customers' => 15,
                'services' => 15,
                'users' => 7,
                'system_settings' => 0,
                'user_settings' => 15,
                'webhooks' => 0,
                'blocked_periods' => 15,
            ]);
        }
    }

    /**
     * Downgrade method.
     */
    public function down(): void
    {
        $this->db->delete('roles', ['slug' => 'company_admin']);
    }
}
