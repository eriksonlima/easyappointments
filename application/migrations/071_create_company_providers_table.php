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

class Migration_Create_company_providers_table extends EA_Migration
{
    /**
     * Upgrade method.
     */
    public function up(): void
    {
        if (!$this->db->table_exists('company_providers')) {
            $this->dbforge->add_field([
                'id_companies' => [
                    'type' => 'BIGINT',
                    'constraint' => '20',
                    'unsigned' => true,
                    'null' => false,
                ],
                'id_users_provider' => [
                    'type' => 'INT',
                    'constraint' => '11',
                    'null' => false,
                ],
                'working_plan' => [
                    'type' => 'TEXT',
                    'null' => true,
                ],
                'working_plan_exceptions' => [
                    'type' => 'TEXT',
                    'null' => true,
                ],
                'notes' => [
                    'type' => 'TEXT',
                    'null' => true,
                ],
            ]);

            $this->dbforge->add_key(['id_companies', 'id_users_provider'], true);
            $this->dbforge->add_key('id_companies');
            $this->dbforge->add_key('id_users_provider');

            $this->dbforge->create_table('company_providers', true, ['engine' => 'InnoDB']);

            $this->db->query(
                '
                ALTER TABLE `' .
                    $this->db->dbprefix('company_providers') .
                    '`
                    ADD CONSTRAINT `company_providers_companies` FOREIGN KEY (`id_companies`) REFERENCES `' .
                    $this->db->dbprefix('companies') .
                    '` (`id`)
                    ON DELETE CASCADE
                    ON UPDATE CASCADE
            ',
            );

            $this->db->query(
                '
                ALTER TABLE `' .
                    $this->db->dbprefix('company_providers') .
                    '`
                    ADD CONSTRAINT `company_providers_users_provider` FOREIGN KEY (`id_users_provider`) REFERENCES `' .
                    $this->db->dbprefix('users') .
                    '` (`id`)
                    ON DELETE CASCADE
                    ON UPDATE CASCADE
            ',
            );
        }
    }

    /**
     * Downgrade method.
     */
    public function down(): void
    {
        if ($this->db->table_exists('company_providers')) {
            $this->db->query(
                'ALTER TABLE `' .
                    $this->db->dbprefix('company_providers') .
                    '` DROP FOREIGN KEY `company_providers_companies`',
            );

            $this->db->query(
                'ALTER TABLE `' .
                    $this->db->dbprefix('company_providers') .
                    '` DROP FOREIGN KEY `company_providers_users_provider`',
            );

            $this->dbforge->drop_table('company_providers');
        }
    }
}
