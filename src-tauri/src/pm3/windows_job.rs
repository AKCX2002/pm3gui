use std::io;
use std::ptr::{null, null_mut};

use windows_sys::Win32::Foundation::{CloseHandle, HANDLE};
use windows_sys::Win32::System::JobObjects::{
    AssignProcessToJobObject, CreateJobObjectW, JobObjectExtendedLimitInformation,
    SetInformationJobObject, TerminateJobObject, JOBOBJECT_EXTENDED_LIMIT_INFORMATION,
    JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE,
};
use windows_sys::Win32::System::Threading::{OpenProcess, PROCESS_SET_QUOTA, PROCESS_TERMINATE};

use super::error::Pm3Error;

#[derive(Debug)]
pub struct WindowsProcessJob {
    handle: HANDLE,
}

unsafe impl Send for WindowsProcessJob {}
unsafe impl Sync for WindowsProcessJob {}

impl WindowsProcessJob {
    pub fn create() -> Result<Self, Pm3Error> {
        let handle = unsafe { CreateJobObjectW(null(), null()) };
        if handle.is_null() {
            return Err(last_error("无法创建 Windows Job Object"));
        }
        let mut information: JOBOBJECT_EXTENDED_LIMIT_INFORMATION = unsafe { std::mem::zeroed() };
        information.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
        let result = unsafe {
            SetInformationJobObject(
                handle,
                JobObjectExtendedLimitInformation,
                &information as *const _ as *const _,
                std::mem::size_of_val(&information) as u32,
            )
        };
        if result == 0 {
            unsafe { CloseHandle(handle) };
            return Err(last_error("无法配置 Windows Job Object"));
        }
        Ok(Self { handle })
    }

    pub fn assign_pid(&self, pid: u32) -> Result<(), Pm3Error> {
        let process = unsafe { OpenProcess(PROCESS_SET_QUOTA | PROCESS_TERMINATE, 0, pid) };
        if process.is_null() {
            return Err(last_error("无法打开 PM3 进程"));
        }
        let result = unsafe { AssignProcessToJobObject(self.handle, process) };
        unsafe { CloseHandle(process) };
        if result == 0 {
            return Err(last_error("无法把 PM3 进程加入 Job Object"));
        }
        Ok(())
    }

    pub fn terminate(&self, exit_code: u32) -> Result<(), Pm3Error> {
        let result = unsafe { TerminateJobObject(self.handle, exit_code) };
        if result == 0 {
            return Err(last_error("无法终止 PM3 进程树"));
        }
        Ok(())
    }
}

impl Drop for WindowsProcessJob {
    fn drop(&mut self) {
        if !self.handle.is_null() {
            unsafe { CloseHandle(self.handle) };
            self.handle = null_mut();
        }
    }
}

fn last_error(context: &str) -> Pm3Error {
    Pm3Error::LaunchFailed {
        detail: format!("{context}：{}", io::Error::last_os_error()),
    }
}
